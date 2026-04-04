// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IDepositV2 {
    struct VaultPosition {
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
    }
    
    function deposit(address token) external;
    function withdraw(address token) external;
    function invest() external;
    function rebalance() external;
}