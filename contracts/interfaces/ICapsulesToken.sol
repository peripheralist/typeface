// SPDX-License-Identifier: GPL-3.0

/// @title Interface for Capsules Token

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

struct Capsule {
    uint256 id;
    bytes3 color;
    uint256 fontWeight;
    bytes4[16][8] text;
    bool isPure;
    bool isLocked;
}

interface ICapsulesToken {
    event MintCapsule(
        uint256 indexed id,
        address indexed to,
        bytes3 indexed color,
        bytes4[16][8] text,
        uint256 fontWeight
    );
    event SetCapsulesMetadata(address _capsulesMetadata);
    event SetCreatorFeeReceiver(address _address);
    event SetPureColors(bytes3[] colors);
    event SetRoyalty(uint256 royalty);
    event LockMetadata();
    event LockCapsule(uint256 capsuleId);
    event EditCapsule(
        uint256 indexed id,
        bytes4[16][8] text,
        uint256 fontWeight
    );
    event Withdraw(address to, uint256 amount);

    function capsuleOf(uint256 capsuleId)
        external
        view
        returns (Capsule memory capsule);

    function isPureColor(bytes3 color) external view returns (bool);

    function isLocked(uint256 capsuleId) external view returns (bool);

    function svgOf(uint256 capsuleId, bool square)
        external
        view
        returns (string memory);

    function mint(
        bytes3 color,
        bytes4[16][8] calldata text,
        uint256 fontWeight,
        bool lock
    ) external payable returns (uint256);

    function mintPureColorForFontWeight(
        address to,
        uint256 fontWeight,
        bytes4[16][8] calldata text
    ) external returns (uint256 capsuleId);

    function lockCapsule(uint256 capsuleId) external;

    function withdraw() external;

    function editCapsule(
        uint256 capsuleId,
        bytes4[16][8] calldata text,
        uint256 fontWeight,
        bool lock
    ) external;

    function burn(uint256 capsuleId) external;

    function setCapsulesMetadata(address _capsulesMetadata) external;

    function setCreatorFeeReceiver(address _creatorFeeReceiver) external;

    function setRoyalty(uint256 _royalty) external;

    function pause() external;

    function unpause() external;
}
