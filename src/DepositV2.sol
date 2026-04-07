// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {TickMath} from "lib/v3-core/contracts/libraries/TickMath.sol";
import {LiquidityAmounts} from "lib/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {IUniswapV3Pool} from "lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "lib/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

// internal imports
import {IDepositV2} from "src/interfaces/IDepositV2.sol";

contract DepositV2 is IDepositV2, Ownable {
    IUniswapV3Pool public immutable POOL;
    IUniswapV3Factory public immutable FACTORY;

    uint256 public constant NULL = 0;

    constructor(IUniswapV3Pool _pool, IUniswapV3Factory _factory) Ownable(msg.sender) {
        POOL = _pool;
        FACTORY = _factory;
    }

    // allowed pair
    mapping(address => bool) internal allowedPool;

    // tick range mapping
    mapping(address => TickRange) internal poolTickRange;

    /// @notice user deposits a pair of allowed tokens to the contract to be used to provide UniswapV3 liquidity
    function depositTokens(DepositParams memory params) external {
        // verify user is depositing in the right pool
        address _pool = _getPool(params.token0, params.token1, params.fee);
        require(allowedPool[_pool], PoolNotAllowed());

        // restrict zero amounts and address(0)
        require(params.amount0 != NULL || params.amount1 != NULL, InvalidAmount());
        require(params.recipient != address(0), InvalidAddress());

        // determining the liquidity to mint for the tokens
        // @to-do: means we need a current range of ticks to mint within
        TickRange memory range = poolTickRange[_pool];

        int24 _tickLower = range.tickLower;
        int24 _tickUpper = range.tickUpper;

        (uint160 sqrtRatioX96,,,,,,) = POOL.slot0();
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(_tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(_tickUpper);

        uint128 liquidityToMint = LiquidityAmounts.getLiquidityForAmounts(
            sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, params.amount0, params.amount1
        );

        // @to-do: before minting, ensure the current tick is in range of the tick bounds

        // user accounting
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
}
