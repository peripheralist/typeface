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
        bytes3 indexed color
    );
    event SetCapsulesRenderer(address _capsulesRenderer);
    event SetCreatorFeeReceiver(address _address);
    event SetPureColors(bytes3[] colors);
    event SetRoyalty(uint256 royalty);
    event LockRenderer();
    event LockCapsule(uint256 capsuleId);
    event EditCapsule(uint256 indexed id);
    event Withdraw(address to, uint256 amount);

    function capsuleOf(uint256 capsuleId)
        external
        view
        returns (Capsule memory capsule);

    function isPureColor(bytes3 color) external view returns (bool);

    function pureColorForFontWeight(uint256 fontWeight)
        external
        view
        returns (bytes3 color);

    function htmlSafeTextOf(uint256 capsuleId)
        external
        returns (string[8] memory safeText);

    function colorOf(uint256 capsuleId) external view returns (bytes3 color);

    function textOf(uint256 capsuleId)
        external
        view
        returns (bytes4[16][8] memory text);

    function fontWeightOf(uint256 capsuleId)
        external
        view
        returns (uint256 fontWeight);

    function isLocked(uint256 capsuleId) external view returns (bool locked);

    function svgOf(uint256 capsuleId, bool square)
        external
        view
        returns (string memory);

    function mint(bytes3 color, uint256 fontWeight)
        external
        payable
        returns (uint256);

    function mintWithText(
        bytes3 color,
        uint256 fontWeight,
        bytes4[16][8] calldata text
    ) external payable returns (uint256);

    function mintPureColorForFontWeight(address to, uint256 fontWeight)
        external
        returns (uint256 capsuleId);

    function lockCapsule(uint256 capsuleId) external;

    function withdraw() external;

    function editCapsule(
        uint256 capsuleId,
        bytes4[16][8] calldata text,
        uint256 fontWeight,
        bool lock
    ) external;

    function burn(uint256 capsuleId) external;

    function setCapsulesRenderer(address _capsulesRenderer) external;

    function setCreatorFeeReceiver(address _creatorFeeReceiver) external;

    function setRoyalty(uint256 _royalty) external;

    function pause() external;

    function unpause() external;
}
