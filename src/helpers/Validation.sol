// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Errors} from "src/helpers/Errors.sol";
import {INonfungiblePositionManager} from "lib/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

library Validation {
    function isZeroAddress(address account) internal pure {
        require(account != address(0), Errors.ZeroAddress());
    }

    function verifySenderIsNFPM(INonfungiblePositionManager nfpm, address from) internal {
        if (msg.sender != address(nfpm) || from == address(this)) {
            revert Errors.IncorrectSource();
        }
    }

    function isPreviousState(bool oldState, bool newState) internal view {
        require(oldState != newState, Errors.OldState());
    }

    function verifyApprovedPool(bool approved) internal view {
        require(approved, Errors.PoolNotApproved());
    }
}
