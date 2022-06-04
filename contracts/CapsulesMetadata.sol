// SPDX-License-Identifier: GPL-3.0

/// @title Capsules Token
/// @author peri
/// @notice Each Capsule token has a unique color and a custom text rendered as a SVG. The text for a Capsule can be updated at any time by its owner.
/// @dev bytes3 type is used to store the 3 bytes of the rgb hex-encoded color that is unique to each capsule.

pragma solidity 0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./ERC721A.sol";
import "./interfaces/ICapsulesMetadata.sol";

contract CapsulesToken is ICapsulesMetadata {}
