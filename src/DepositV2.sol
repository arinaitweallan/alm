// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {UniswapV3Pool} from "lib/v3-core/contracts/UniswapV3Pool.sol";

contract DepositV2 {
    UniswapV3Pool public immutable POOL;

    constructor(UniswapV3Pool _pool) {
        POOL = _pool;
    }
}