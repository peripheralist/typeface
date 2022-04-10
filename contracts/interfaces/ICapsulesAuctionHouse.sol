// SPDX-License-Identifier: GPL-3.0

/// @title Interface for Capsule Auction Houses

pragma solidity ^0.8.12;

interface ICapsulesAuctionHouse {
    struct Auction {
        // ID for the Capsule (ERC721 token ID)
        uint256 capsuleId;
        // The current highest bid amount
        uint256 amount;
        // The time that the auction started
        uint256 startTime;
        // The time that the auction is scheduled to end
        uint256 endTime;
        // The address of the current highest bid
        address payable bidder;
        // Whether or not the auction has been settled
        bool settled;
    }

    event AuctionCreated(
        uint256 indexed capsuleId,
        uint256 startTime,
        uint256 endTime
    );

    event AuctionBid(
        uint256 indexed capsuleId,
        address sender,
        uint256 value,
        bool extended
    );

    event AuctionExtended(uint256 indexed capsuleId, uint256 endTime);

    event AuctionSettled(
        uint256 indexed capsuleId,
        address winner,
        uint256 amount
    );

    event AuctionTimeBufferUpdated(uint256 timeBuffer);

    event AuctionMinBidIncrementPercentageUpdated(
        uint256 minBidIncrementPercentage
    );

    function settleAuction() external;

    function settleCurrentAndTryCreateNewAuction() external;

    function createBid(uint256 capsuleId) external payable;

    function pause() external;

    function unpause() external;

    function setTimeBuffer(uint256 timeBuffer) external;

    function setMinBidIncrementPercentage(uint8 minBidIncrementPercentage)
        external;
}
