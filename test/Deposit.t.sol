// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {Deposit} from "src/Deposit.sol";
import {Errors} from "src/helpers/Errors.sol";
import {IDeposit} from "src/interfaces/IDeposit.sol";

// external imports
import {INonfungiblePositionManager} from "lib/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract DepositTest is Test {
    // using SafeERC20 for address;

    Deposit depositContract;
    address owner = address(0x290);
    address lp = address(0x111);

    // fork
    uint256 mainnetFork;

    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    // pools
    address constant UNISWAP_DAI_USDC = 0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168; // 0.01% pool
    address constant UNISWAP_ETH_USDC = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640; // 0.05% pool
    address constant UNISWAP_DAI_USDC_005 = 0x6c6Bc977E13Df9b0de53b251522280BB72383700; // 0.05% pool
    address constant UNISWAP_DAI_WETH_03 = 0xC2e9F25Be6257c210d7Adf0D4Cd6E3E881ba25f8; // 0.3% pool

    address constant UNISWAP_DAI_USDT_01 = 0x48DA0965ab2d2cbf1C17C09cFB5Cbe67Ad5B1406;

    // eth mainnet
    address nfpm = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;

    function setUp() external {
        string memory ankrRpc = string.concat("https://rpc.ankr.com/eth/", vm.envString("ANKR_API_KEY"));
        string memory alchemyRpc =
            string.concat("https://eth-mainnet.g.alchemy.com/v2/", vm.envString("ALCHEMY_API_KEY"));
        mainnetFork = vm.createFork(alchemyRpc, 24_700_000);
        vm.selectFork(mainnetFork);

        vm.prank(owner);
        depositContract = new Deposit(nfpm);

        // approve pools
        _approvePool(UNISWAP_DAI_WETH_03);
        _approvePool(UNISWAP_ETH_USDC);
        _approvePool(UNISWAP_DAI_USDT_01);

        // deal tokens to lp
        _dealTokens(lp, dai, weth, 25_000e18, 10e18);
    }

    // internal helper
    function _approvePool(address pool) internal {
        vm.prank(owner);
        depositContract.changePoolStatus(pool, true);
    }

    function _dealTokens(address user, address token0, address token1, uint256 amount0, uint256 amount1) internal {
        deal(token0, user, amount0);
        deal(token1, user, amount1);
        deal(user, 100 ether);
    }

    function _mintNft(
        address user,
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        int24 tickLower,
        int24 tickUpper,
        uint24 fee
    ) internal returns (uint256 tokenId) {
        vm.startPrank(user);
        // IERC20(token0).approve(address(nfpm), type(uint256).max);
        // // IERC20(token1).approve(address(nfpm), 0);
        // IERC20(token1).approve(address(nfpm), type(uint256).max);

        SafeERC20.forceApprove(IERC20(token0), address(nfpm), type(uint256).max);
        SafeERC20.forceApprove(IERC20(token1), address(nfpm), type(uint256).max);

        (tokenId,,,) = INonfungiblePositionManager(nfpm)
            .mint(
                INonfungiblePositionManager.MintParams({
                    token0: token0,
                    token1: token1,
                    fee: fee,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    amount0Desired: amount0,
                    amount1Desired: amount1,
                    amount0Min: 0,
                    amount1Min: 0,
                    recipient: user,
                    deadline: block.timestamp
                })
            );
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/
    function testConstructor() public view {
        // owner, nfpm, factory set
        assertEq(depositContract.owner(), owner);
        assertEq(address(depositContract.NFPM()), nfpm);
        assertEq(address(depositContract.FACTORY()), INonfungiblePositionManager(nfpm).factory());

        require(address(depositContract.NFPM()) != address(0), "zero address");
        require(depositContract.owner() != address(0), "zero address");
    }

    // deposit
    function testZeroAddressReverts() public {
        vm.expectRevert(Errors.ZeroAddress.selector);
        depositContract.deposit(1000, address(0), UNISWAP_ETH_USDC);
    }

    function testNotApprovedPoolAddressReverts() public {
        vm.expectRevert(Errors.PoolNotApproved.selector);
        depositContract.deposit(1000, address(123), UNISWAP_ETH_USDC);
    }

    function testUserNftDirectTransfer() public {
        // lp has tokens from setUp
        uint256 tokenId = _mintNft(lp, dai, weth, 22_000e18, 10e18, -88000, -70000, 500);

        bytes memory data = abi.encode(lp);

        vm.prank(lp);
        INonfungiblePositionManager(nfpm).safeTransferFrom(lp, address(depositContract), tokenId, data);
    }

    function testStateChangesDeposit() public {
        // lp has tokens from setUp
        _dealTokens(lp, dai, usdt, 20_000e18, 20_000e6);
        uint256 tokenId = _mintNft(lp, dai, usdt, 20_000e18, 20_000e6, -1, 1, 100);

        vm.startPrank(lp);
        INonfungiblePositionManager(nfpm).approve(address(depositContract), tokenId);
        depositContract.deposit(tokenId, lp, address(UNISWAP_DAI_USDT_01));
        vm.stopPrank();

        // accessing a standard mapping: tokenOwner(uint256)
        address actualOwner = depositContract.tokenOwner(tokenId);
        assertEq(actualOwner, lp, "foken owner should be the lp");

        // accessing a mapping to an array: ownedTokens(address, uint256)
        // public mapping getters for arrays require an index as the second argument.
        // To check the first token in the list for the LP:
        uint256 firstTokenId = depositContract.ownedTokens(lp, 0);
        assertEq(firstTokenId, tokenId, "first token in list should match tokenId");

        // accessing a standard mapping: ownedTokensIndex(uint256)
        uint256 index = depositContract.ownedTokensIndex(tokenId);
        assertEq(index, 0, "index should be zero for the first token");
    }

    function testNoRecipientRevertsUserNftDirectTransfer() public {
        // lp has tokens from setUp
        uint256 tokenId = _mintNft(lp, dai, weth, 22_000e18, 10e18, -88000, -70000, 500);

        bytes memory data = "";

        vm.prank(lp);
        vm.expectRevert(Errors.DirectTransferNotAllowed.selector);
        INonfungiblePositionManager(nfpm).safeTransferFrom(lp, address(depositContract), tokenId, data);
    }
}
