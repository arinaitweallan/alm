// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

library Errors {
    // zero address
    error ZeroAddress();
    // sender not uniswap
    error IncorrectSource();
    // old state error
    error OldState();
    // not approved pool
    error PoolNotApproved();
    // recipient not encoded
    error RecipientNotSet();
}
