// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Validation} from "src/helpers/Validation.sol";
import {IDeposit} from "src/interfaces/IDeposit.sol";

// external imports
import {INonfungiblePositionManager} from "lib/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {IERC721Receiver} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IUniswapV3Factory} from "lib/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

contract Deposit is IDeposit, IERC721Receiver, Ownable {
    INonfungiblePositionManager public immutable NFPM;
    IUniswapV3Factory public immutable FACTORY;

    // token ownership data strucuture
    mapping(address => uint256[]) private ownedTokens; // Mapping from owner address to list of owned token IDs
    mapping(uint256 => uint256) private ownedTokensIndex; // Mapping from token ID to index of the owner tokens list (for removal without loop)
    mapping(uint256 => address) private tokenOwner;

    // approved pools mapping
    mapping(address => bool) public approvedPool;

    // deployer is the owner of the contract
    constructor(address _nonfungiblePositionManager, address _factory) Ownable(msg.sender) {
        Validation.isZeroAddress(_nonfungiblePositionManager);
        Validation.isZeroAddress(_factory);
        NFPM = INonfungiblePositionManager(_nonfungiblePositionManager);
        FACTORY = IUniswapV3Factory(_nonfungiblePositionManager.factory());
    }

    /// @dev function to let the user deposit their NonFungiblePositionManager NFT
    /// @param tokenId tokenId of the nft to deposit
    /// @param receiver address to receiver ownership of the nft
    /// @param pool address is computed off-chain
    function deposit(uint256 tokenId, address receiver, address pool) external {
        // checks
        Validation.isZeroAddress(receiver);
        // as if we should allow nfts of only one specific pool
        // say weth/usdc 3000 pool, only these nfts, how can we verify this
        bool _approved = _isApprovedPool(pool);
        Validation.verifyApprovedPool(_approved);

        // effects
        NFPM.safeTransferFrom(msg.sender, address(this), tokenId, abi.encode(receiver));
        // interactions
    }

    /// @dev function to let the user withdraw their NonFungiblePositionManager NFT
    /// @param tokenId tokenId of the nft to withdraw
    /// @param recipient address to receive the nft
    /// @param data data the receiver might need to pass
    function withdraw(uint256 tokenId, address recipient, bytes calldata data) external {
        // check owner
        address _sender = _msgSender();
        require(_sender == tokenOwner[tokenId], UnAuthorized());

        // update ownership state
        _removeTokenFromOwner(_sender, tokenId);

        // transfer nft to owner
        NFPM.safeTransferFrom(address(this), recipient, tokenId, data);
        emit NFTWithdraw(_sender, tokenId);
    }

    /// @dev UniswapV3 onERC721Received to trigger on receiving the LP nft
    function onERC721Received(
        address,
        /*operator*/
        address from,
        uint256 tokenId,
        bytes calldata data
    )
        external
        returns (bytes4)
    {
        // verify sender is NFPM
        Validation.verifySender(NFPM, from);

        // decode owner
        address recipient;
        if (data.length != 0) {
            recipient = abi.decode(data, (address));
        }

        // differentiate if its a direct deposit or user invoked deposit function on this contract

        // add token to owner in either of the cases
        _addTokenToOwner(recipient, tokenId);
        emit NFTDeposit(recipient, tokenId);

        // should we mint them ownership
        return IERC721Receiver.onERC721Received.selector;
    }

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

    // getters
    function _isApprovedPool(address pool) internal view returns (bool) {
        return approvedPool[pool];
    }

    /*//////////////////////////////////////////////////////////////
                                 ADMIN
    //////////////////////////////////////////////////////////////*/
    function changePoolStatus(address pool, bool approved) external onlyOwner {
        Validation.isZeroAddress(pool);
        bool _approved = approvedPool[pool];
        Validation.isPreviousState(_approved, approved);

        approvedPool[pool] = approved;
        emit PoolStatusChanged(pool, approved);
    }
}
