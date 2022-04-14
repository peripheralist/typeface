// SPDX-License-Identifier: GPL-3.0

/// @title Capsules Token
/// @author peri
/// @notice Each Capsule token has a unique color, custom text rendered as a SVG, and a single vote for a Delegate address. The text and Delegate vote for a Capsule can be updated at any time by its owner. The address with >50% of Delegate votes has permission to withdraw fees earned from the primary mint, change the fee for editing Capsule texts, and initiate and manage the auction of reserved Capsules.
/// @dev bytes3 type is used to store the 3 bytes of the rgb hex-encoded color that is unique to each capsule.

pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./interfaces/IDelegate721Enumerable.sol";

contract Delegate721Enumerable is IDelegate721Enumerable, ERC721Enumerable {
    /// @notice Require that the sender is the delegate
    modifier onlyDelegate() {
        require(isDelegate(msg.sender), "Sender is not the Delegate");
        _;
    }

    uint256 internal primarySupply;

    constructor(
        string memory name,
        string memory symbol,
        uint256 _primarySupply
    ) ERC721(name, symbol) {
        primarySupply = _primarySupply;
    }

    /// Delegate vote of a token id
    mapping(uint256 => address) public delegateVoteOf;

    /// @notice Returns true if address has >50% of current delegate votes
    /// @dev Primary mint must complete before delegate is recognized
    /// @param _address address to check delegate status for
    function isDelegate(address _address) public view returns (bool) {
        // We use `mintedCount` instead of `totalSupply()` to allow for burning tokens, which reduce `totalSupply()`
        if (totalSupply() < primarySupply) return false;

        uint256 voteCount = 0;

        // Tally votes from all Capsules
        for (uint256 i; i < totalSupply(); i++) {
            if (delegateVoteOf[i] == _address) voteCount++;
            // `_address` has >50% of votes
            if (voteCount > (totalSupply() / 2)) return true;
        }

        return false;
    }

    /// @notice Updates delegate vote for Capsule
    /// @param capsuleId id of Capsule token
    /// @param delegate address of Delegate to vote for
    function _setDelegateVote(uint256 capsuleId, address delegate) internal {
        delegateVoteOf[capsuleId] = delegate;

        emit SetDelegateVote(capsuleId, delegate);
    }
}
