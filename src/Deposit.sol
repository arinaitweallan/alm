// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Validation} from "src/helpers/Validation.sol";

// external imports
import {INonfungiblePositionManager} from "lib/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {IERC721Receiver} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

contract Deposit is IERC721Receiver {
    INonfungiblePositionManager public immutable NFPM;

    // token ownership data strucuture
    mapping(address => uint256[]) private ownedTokens; // Mapping from owner address to list of owned token IDs
    mapping(uint256 => uint256) private ownedTokensIndex; // Mapping from token ID to index of the owner tokens list (for removal without loop)
    mapping(address => uint256) private tokenOwner;

    constructor(address _nonfungiblePositionManager) {
        Validation.isZeroAddress(_nonfungiblePositionManager);
        NFPM = INonfungiblePositionManager(_nonfungiblePositionManager);
    }

    /// @dev function to let the user deposit their NonFungiblePositionManager NFT
    /// @param tokenId tokenId of the nft to deposit
    /// @param receiver address to receiver ownership of the nft
    function deposit(uint256 tokenId, address receiver) external {
        // checks
        Validation.isZeroAddress(receiver);
        // effects
        NFPM.safeTransferFrom(msg.sender, address(this), tokenId, abi.encode(receiver));
        // interactions
    }

    /// @dev function to let the user withdraw their NonFungiblePositionManager NFT
    /// @param tokenId tokenId of the nft to withdraw
    function withdraw(uint256 tokenId) external {}

    /// @dev UniswapV3 onERC721Received to trigger on receiving the LP nft
    function onERC721Received(address /*operator*/, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4)
    {
        // verify sender is NFPM
        Validation.verifySenderIsNFPM(NFPM, from);

        // differentiate if its a direct deposit or user invoked deposit function on this contract

        // add token to owner in either of the cases
        _addTokenToOwner(from, tokenId);
    }

    // internal functions
    function _addTokenToOwner(address to, uint256 tokenId) internal {
        ownedTokensIndex[tokenId] = ownedTokens[to].length;

        ownedTokens[to].push(tokenId);
        tokenOwner[tokenId] = to;
    }

    function _removeTokenFromOwner(address from, uint256 tokenId) internal {
        uint256 lastTokenIndex = ownedTokens[from].length - 1;
        uint256 tokenIndex = ownedTokensIndex[tokenId];

        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = ownedTokens[from][lastTokenIndex];

            ownedTokens[from][tokenIndex] = lastTokenId;
            ownedTokensIndex[lastTokenId] = tokenIndex;
        }

        ownedTokens[from].pop(); // remove from token owner
        delete ownedTokensIndex[tokenId]; // owned tokens index deleted
        delete tokenOwner[tokenId]; // remove the token from the token owner mapping
    }
}
