// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Validation} from "src/helpers/Validation.sol";

contract Deposit {
    mapping(address => uint256) public tokenOwner;

    constructor() {}

    /// @dev function to let the user deposit their NonFungiblePositionManager NFT
    /// @param tokenId tokenId of the nft to deposit
    /// @param receiver address to receiver ownership of the nft
    function deposit(uint256 tokenId, address receiver) external {
        // checks
        Validation.isZeroAddress(receiver);
        // effects
        // interactions
    }

    /// @dev function to let the user withdraw their NonFungiblePositionManager NFT
    /// @param tokenId tokenId of the nft to withdraw
    function withdraw(uint256 tokenId) external {}
}
