// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Errors} from "src/helpers/Errors.sol";
import {INonfungiblePositionManager} from "lib/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

library Validation {
    function isZeroAddress(address account) internal pure {
        require(account != address(0), Errors.ZeroAddress());
    }

    function verifySender(INonfungiblePositionManager nfpm, address from) internal view {
        if (msg.sender != address(nfpm) || from == address(this)) {
            revert Errors.IncorrectSource();
        }
    }

    function isPreviousState(bool oldState, bool newState) internal pure {
        require(oldState != newState, Errors.OldState());
    }

    function verifyApprovedPool(bool approved) internal pure {
        require(approved, Errors.PoolNotApproved());
    }

    function decodeRecipient(bytes memory data) internal pure returns (address recipient) {
        if (data.length != 0) {
            recipient = abi.decode(data, (address));
        } else {
            revert Errors.RecipientNotSet();
        }
    }

    function noDirectTransfers(address operator) internal pure {
        require(operator == address(this), Errors.DirectTransferNotAllowed());
    }
}
