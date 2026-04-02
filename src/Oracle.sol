// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {AggregatorV3Interface} from "lib/AggregatorV3Interface.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IAaveOracle} from "lib/IAaveOracle.sol";

// internal imports
import {Validation} from "src/helpers/Validation.sol";

contract Oracle is Ownable {
    AggregatorV3Interface public feed;
    AggregatorV3Interface public sequencerUptimeFeed;
    IAaveOracle public aaveOracle;

    // Uniswap TWAP

    struct FeedConfig {
        uint256 maxFeedAge;
    }

    constructor(IAaveOracle _aaveOracle, AggregatorV3Interface _feed) Ownable(msg.sender) {
        aaveOracle = _aaveOracle;
        feed = _feed;
    }

    function getChainlinkPrice() external view returns (uint256) {
        // (, int256 answer,, uint256 updatedAt,) = feed.latestRoundData();
        // if (updatedAt + maxFeedAge < block.timestamp || answer <= 0) {
        //     // revert ChainlinkPriceError();
        // }
        // return answer;
    }

    function getAavePrice(address token) public view returns (uint256 price) {
        price = aaveOracle.getAssetPrice(token);
        Validation.isPriceZero(price);
    }

    // admin
    function setFeed(AggregatorV3Interface feed_) external onlyOwner {}

    function setSequencerUptimeFeed(AggregatorV3Interface sequencerFeed) external onlyOwner {}
}
