// SPDX-License-Identifier: GPL-3.0

/// @title Interface for Capsules Token

pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IDelegate721Enumerable is IERC721Enumerable {
    event SetDelegateVote(uint256 indexed id, address indexed delegate);

    function isDelegate(address _address) external view returns (bool);
}
