// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {UniswapV3Pool} from "lib/v3-core/contracts/UniswapV3Pool.sol";

// internal imports
import {IDepositV2} from "src/interfaces/IDepositV2.sol";

contract DepositV2 is IDepositV2 {
    UniswapV3Pool public immutable POOL;

    constructor(UniswapV3Pool _pool) {
        POOL = _pool;
    }
}