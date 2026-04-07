// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IDepositV2 {
    event PoolAdded(address indexed pool);

    // errors
    error PoolNotAllowed();
    error InvalidAmount();
    error InvalidAddress();

    struct DepositParams {
        address token0;
        address token1;
        uint24 fee;
        uint256 amount0;
        uint256 amount1;
        address recipient;
    }

    // struct VaultPosition {
    //     int24 tickLower;
    //     int24 tickUpper;
    //     uint128 liquidity;
    // }
    
    // function deposit(address token) external;
    // function withdraw(address token) external;
    // function invest() external;
    // function rebalance() external;
}