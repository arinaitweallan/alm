// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Errors} from "src/helpers/Errors.sol";

library Validation {
    function isZeroAddress(address account) internal pure {
        require(account != address(0), Errors.ZeroAddress());
    }
}
