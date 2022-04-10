// SPDX-License-Identifier: GPL-3.0

/// @title Capsules Auction House
/// @author peri

// LICENSE
// CapsulesAuctionHouse.sol is a modified version of Zora's AuctionHouse.sol:
// https://github.com/ourzora/auction-house/blob/54a12ec1a6cf562e49f0a4917990474b11350a2d/contracts/AuctionHouse.sol
//
// AuctionHouse.sol source code Copyright Zora licensed under the GPL-3.0 license.
// With modifications by Nounders DAO and Capsules.

pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "./interfaces/ICapsulesAuctionHouse.sol";
import "./interfaces/ICapsulesToken.sol";
import "./interfaces/IWETH.sol";

contract CapsulesAuctionHouse is
    ICapsulesAuctionHouse,
    ERC721Holder,
    Pausable,
    ReentrancyGuard
{
    /**
     * @notice Require that the sender is the delegate.
     */
    modifier onlyDelegate() {
        require(capsules.isDelegate(msg.sender), "Sender is not the Delegate");
        _;
    }

    // The Capsules ERC721 token contract
    ICapsulesToken public capsules;

    // The address of the WETH contract
    address public weth;

    // The minimum amount of time left in an auction after a new bid is created
    uint256 public timeBuffer;

    // The minimum price accepted in an auction
    uint256 public reservePrice;

    // The minimum percentage difference between the last bid amount and the current bid
    uint8 public minBidIncrementPercentage;

    // The duration of a single auction
    uint256 public duration;

    // The active auction
    ICapsulesAuctionHouse.Auction public auction;

    mapping(uint256 => bytes3) colorForId;

    constructor(
        address _capsules,
        address _weth,
        uint256 _timeBuffer,
        uint256 _reservePrice,
        uint8 _minBidIncrementPercentage,
        uint256 _duration
    ) {
        capsules = ICapsulesToken(_capsules);
        weth = _weth;
        timeBuffer = _timeBuffer;
        reservePrice = _reservePrice;
        minBidIncrementPercentage = _minBidIncrementPercentage;
        duration = _duration;

        _pause();
    }

    /**
     * @notice Settle the current auction, then try minting a new Capsule and putting it up for auction.
     */
    function settleCurrentAndTryCreateNewAuction()
        external
        override
        nonReentrant
        whenNotPaused
    {
        _settleAuction();
        _tryCreateAuction();
    }

    /**
     * @notice Settle the current auction.
     * @dev This function can only be called when the contract is paused.
     */
    function settleAuction() external override whenPaused nonReentrant {
        _settleAuction();
    }

    /**
     * @notice Create a bid for a Capsule, with a given amount.
     * @dev This contract only accepts payment in ETH.
     */
    function createBid(uint256 capsuleId)
        external
        payable
        override
        nonReentrant
    {
        ICapsulesAuctionHouse.Auction memory _auction = auction;

        require(_auction.capsuleId == capsuleId, "Capsule not up for auction");
        require(block.timestamp < _auction.endTime, "Auction expired");
        require(msg.value >= reservePrice, "Must send at least reservePrice");
        require(
            msg.value >=
                _auction.amount +
                    ((_auction.amount * minBidIncrementPercentage) / 100),
            "Must send more than last bid by minBidIncrementPercentage amount"
        );

        address payable lastBidder = _auction.bidder;

        // Refund the last bidder, if applicable
        if (lastBidder != address(0)) {
            _safeTransferETHWithFallback(lastBidder, _auction.amount);
        }

        auction.amount = msg.value;
        auction.bidder = payable(msg.sender);

        // Extend the auction if the bid was received within `timeBuffer` of the auction end time
        bool extended = _auction.endTime - block.timestamp < timeBuffer;
        if (extended) {
            auction.endTime = _auction.endTime = block.timestamp + timeBuffer;
        }

        emit AuctionBid(_auction.capsuleId, msg.sender, msg.value, extended);

        if (extended) {
            emit AuctionExtended(_auction.capsuleId, _auction.endTime);
        }
    }

    /**
     * @notice Pause the Capsules auction house.
     * @dev This function can only be called by the delegate when the
     * contract is unpaused. While no new auctions can be started when paused,
     * anyone can settle an ongoing auction.
     */
    function pause() external override onlyDelegate {
        _pause();
    }

    /**
     * @notice Unpause the Capsules auction house.
     * @dev This function can only be called by the delegate when the
     * contract is paused. If required, this function will start a new auction.
     */
    function unpause() external override onlyDelegate {
        _unpause();

        if (auction.startTime == 0 || auction.settled) {
            _tryCreateAuction();
        }
    }

    /**
     * @notice Set the auction time buffer.
     * @dev Only callable by the delegate.
     */
    function setTimeBuffer(uint256 _timeBuffer) external override onlyDelegate {
        timeBuffer = _timeBuffer;

        emit AuctionTimeBufferUpdated(_timeBuffer);
    }

    /**
     * @notice Set the auction minimum bid increment percentage.
     * @dev Only callable by the delegate.
     */
    function setMinBidIncrementPercentage(uint8 _minBidIncrementPercentage)
        external
        override
        onlyDelegate
    {
        minBidIncrementPercentage = _minBidIncrementPercentage;

        emit AuctionMinBidIncrementPercentageUpdated(
            _minBidIncrementPercentage
        );
    }

    /**
     * @notice Create an auction if an auction color can be minted.
     * @dev Store the auction details in the `auction` state variable and emit an AuctionCreated event.
     */
    function _tryCreateAuction() internal {
        try capsules.mintAuctionColor() returns (uint256 capsuleId) {
            if (capsuleId != 0) {
                uint256 startTime = block.timestamp;
                uint256 endTime = startTime + duration;

                auction = Auction({
                    capsuleId: capsuleId,
                    amount: 0,
                    startTime: startTime,
                    endTime: endTime,
                    bidder: payable(0),
                    settled: false
                });

                emit AuctionCreated(capsuleId, startTime, endTime);
            }
        } catch Error(string memory) {
            _pause();
        }
    }

    /**
     * @notice Settle an auction, finalizing the bid and paying out to the Capsules mint admin.
     * @dev If there are no bids, the Capsule is burned.
     */
    function _settleAuction() internal {
        ICapsulesAuctionHouse.Auction memory _auction = auction;

        require(_auction.startTime != 0, "Auction hasn't begun");
        require(!_auction.settled, "Auction has already been settled");
        require(
            block.timestamp >= _auction.endTime,
            "Auction hasn't completed"
        );

        auction.settled = true;

        if (_auction.bidder == address(0)) {
            capsules.burn(_auction.capsuleId);
        } else {
            capsules.transferFrom(
                address(this),
                _auction.bidder,
                _auction.capsuleId
            );
        }

        // Send funds to Capsules contract
        if (_auction.amount > 0) {
            _safeTransferETHWithFallback(
                payable(address(capsules)),
                _auction.amount
            );
        }

        emit AuctionSettled(
            _auction.capsuleId,
            _auction.bidder,
            _auction.amount
        );
    }

    /**
     * @notice Transfer ETH. If the ETH transfer fails, wrap the ETH and try to send it as WETH.
     */
    function _safeTransferETHWithFallback(address to, uint256 amount) internal {
        if (!_safeTransferETH(to, amount)) {
            IWETH(weth).deposit{value: amount}();
            IERC20(weth).transfer(to, amount);
        }
    }

    /**
     * @notice Transfer ETH and return the success status.
     * @dev This function only forwards 30,000 gas to the callee.
     */
    function _safeTransferETH(address to, uint256 value)
        internal
        returns (bool)
    {
        (bool success, ) = to.call{value: value, gas: 30_000}(new bytes(0));
        return success;
    }
}
