// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IDeposit {
    error UnAuthorized();
    error RecipientNotSet();

    // events
    event PoolStatusChanged(address indexed pool, bool status);
    event NFTDeposit(address indexed receiver, uint256 indexed tokenId);
    event NFTWithdraw(address indexed owner, uint256 tokenId);
}
