// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {TransferHelper} from "lib/v3-periphery/contracts/libraries/TransferHelper.sol";
import {TickMath} from "lib/v3-core/contracts/libraries/TickMath.sol";
import {LiquidityAmounts} from "lib/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {IUniswapV3Pool} from "lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "lib/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3MintCallback} from "lib/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol";
import {LiquidityManagement} from "lib/v3-periphery/contracts/base/LiquidityManagement.sol";

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

// internal imports
import {IDepositV2} from "src/interfaces/IDepositV2.sol";

contract DepositV2 is IDepositV2, ERC20, Ownable, LiquidityManagement {
    IUniswapV3Pool public immutable POOL;
    IUniswapV3Factory public immutable FACTORY;

    uint256 public constant NULL = 0;
    uint128 public constant MAX_FEES = type(uint128).max;

    // fees handling
    uint256 public globalFeeIndex0; // cumulative fees per share for token0
    uint256 public globalFeeIndex1; // cumulative fees per share for token1

    mapping(address => uint256) public userFeeIndex0;
    mapping(address => uint256) public userFeeIndex1;

    mapping(address => uint256) public accruedFees0;
    mapping(address => uint256) public accruedFees1;

    // allowed pair
    mapping(address => bool) internal allowedPool;
    // tick range mapping
    mapping(address => TickRange) internal poolTickRange;

    constructor(
        IUniswapV3Pool _pool /*IUniswapV3Factory _factory*/
    )
        ERC20("ALM-SHARES", "ALMS")
        Ownable(msg.sender)
    {
        POOL = _pool;
        // FACTORY = _factory;
        FACTORY = _pool.factory();
    }

    /// @notice user deposits a pair of allowed tokens to the contract to be used to provide UniswapV3 liquidity
    function depositTokens(DepositParams memory params) external {
        // verify user is depositing in the right pool
        address _pool = _getPool(params.token0, params.token1, params.fee);
        require(allowedPool[_pool], PoolNotAllowed());

        // restrict zero amounts and address(0)
        require(params.amount0 != NULL || params.amount1 != NULL, InvalidAmount());
        require(params.recipient != address(0), InvalidAddress());

        // harvest
        harvest(_pool);
        _updateUser(params.recipient);

        // determining the liquidity to mint for the tokens
        // @to-do: means we need a current range of ticks to mint within
        TickRange memory range = poolTickRange[_pool];

        int24 _tickLower = range.tickLower;
        int24 _tickUpper = range.tickUpper;

        // @to-do: before minting, ensure the current tick is in range of the tick bounds

        AddLiquidityParams memory addParams = AddLiquidityParams({
            token0: params.token0,
            token1: params.token1,
            fee: params.fee,
            recipient: address(this),
            tickLower: _tickLower,
            tickUpper: _tickUpper,
            amount0Desired: params.amount0,
            amount1Desired: params.amount1,
            amount0Min: 0,
            amount1Min: 0
        });

        (uint128 liquidity, uint256 amountUsed0, uint256 amountUsed1,) = addLiquidity(addParams);

        // @to-do: handle slippage

        // @reminder: next to do
        // q how do i update these?
        // userFeeIndex0[params.recipient] +=
        // userFeeIndex0[params.recipient] +=
        // @to-do: handle fees

        // @to-do: update user fee index

        // user accounting (mint shares eqaul to liquidity minted)
        _mint(params.recipient, uint256(liquidity));
        emit Deposit(params.recipient, params.token0, params.token1);
    }

    function harvest(address pool) public {
        // collect fees from UniswapV3Pool
        (uint256 collected0, uint256 collected1) = _collectFromPool(pool);

        // update the global fee index
        // We use a large multiplier (like 1e18 or 1e36) to prevent rounding errors
        if (totalSupply() > 0) {
            globalFeeIndex0 += (collected0 * 1e18) / totalSupply();
            globalFeeIndex1 += (collected1 * 1e18) / totalSupply();
        }
    }

    // token0 might be weth, token1 be usdc but the fee tiers are different say 0.01%, 0.05%
    // q which mapping do we use to identify the pool?
    // mapping(address => bool) internal allowedPool;
    // mapping(addres => (mapping(address =>()))

    function whitelistPool(address token0, address token1, uint24 fee) external onlyOwner {
        address pool = _getPool(token0, token1, fee);

        allowedPool[pool] = true;
        emit PoolAdded(pool);
    }

    // internal

    function _getPool(address token0, address token1, uint24 fee) internal returns (address pool) {
        pool = FACTORY.getPool(token0, token1, fee);
    }

    function _pullTokens(address token0, address token1, uint256 amount0, uint256 amount1) internal {
        TransferHelper.safeTransferFrom(token0, msg.sender, address(this), amount0);
        TransferHelper.safeTransferFrom(token1, msg.sender, address(this), amount1);
    }

    function _collectFromPool(address _pool) internal returns (uint256 amount0, uint256 amount1) {
        // simplfy this get ticks
        // @audit: these must the ticks used when providing liquidity
        // we must track the last used ticks
        // @to-do:
        TickRange memory range = poolTickRange[_pool];

        int24 _tickLower = range.tickLower;
        int24 _tickUpper = range.tickUpper;
        (amount0, amount1) = POOL.collect(address(this), _tickLower, _tickUpper, MAX_FEES, MAX_FEES);
    }

    function _calculateEarned(address user) internal view returns (uint256 earned0, uint256 earned1) {
        uint256 shares = balanceOf(user);
        if (shares == 0) return (0, 0);

        // earnings = shares * (current global - user's last snapshot)
        // we divide by 1e18 because we multiplied by 1e18 in the harvest() function
        earned0 = (shares * (globalFeeIndex0 - userFeeIndex0[user])) / 1e18;
        earned1 = (shares * (globalFeeIndex1 - userFeeIndex1[user])) / 1e18;
    }

    function _updateUser(address user) internal {
        // calculate what they earned since their last interaction
        (uint256 earned0, uint256 earned1) = _calculateEarned(user);

        // add those earnings to a "pending" balance
        accruedFees0[user] += earned0;
        accruedFees1[user] += earned1;

        // set their "meter" to the current global state
        userFeeIndex0[user] = globalFeeIndex0;
        userFeeIndex1[user] = globalFeeIndex1;
    }

    function _addLiquidity() internal {}
}

// (uint160 sqrtRatioX96,,,,,,) = POOL.slot0();
// uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(_tickLower);
// uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(_tickUpper);

// uint128 liquidityToMint = LiquidityAmounts.getLiquidityForAmounts(
//     sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, params.amount0, params.amount1
// );
// require all amounts are used
// q what data should we pass here
// (uint256 amount0, uint256 amount1) =
//     POOL.mint(params.recipient, _tickLower, _tickUpper, liquidityToMint, abi.encode(msg.sender));
// require(amount0 == params.amount0 && amount1 == params.amount1, AmountsNotFullyUsed());

// @to-do: handle callback

// refund unused tokens to the user
// if (params.amount0 > amountUsed0) {
//     TransferHelper.safeTransfer(params.token0, msg.sender, params.amount0 - amountUsed0);
// }
// if (params.amount1 > amountUsed1) {
//     TransferHelper.safeTransfer(params.token1, msg.sender, params.amount1 - amountUsed1);
// }
