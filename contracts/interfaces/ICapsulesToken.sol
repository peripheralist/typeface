// SPDX-License-Identifier: GPL-3.0

/// @title Interface for Capsules Token

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

struct Capsule {
    uint256 id;
    bytes3 color;
    uint256 fontWeight;
    bytes16[8] text;
}

interface ICapsulesToken {
    event MintCapsule(
        uint256 indexed id,
        address indexed to,
        bytes3 indexed color,
        bytes16[8] text,
        uint256 fontWeight
    );
    event ClaimCapsule(
        uint256 indexed id,
        address indexed to,
        bytes3 indexed color,
        bytes16[8] text,
        uint256 fontWeight
    );
    event SetCapsulesMetadata(address _capsulesMetadata);
    event SetCreatorFeeReceiver(address _address);
    event SetClaimCount(address indexed _address, uint256 number);
    event SetPureColors(bytes3[] colors);
    event SetRoyalty(uint256 royalty);
    event LockMetadata();
    event EditCapsule(uint256 indexed id, bytes16[8] text, uint256 fontWeight);
    event Withdraw(address to, uint256 amount);

    function capsuleFor(uint256 capsuleId)
        external
        view
        returns (Capsule memory capsule);

    function isPureColor(bytes3 color) external view returns (bool);

    function mint(
        bytes3 color,
        bytes16[8] calldata text,
        uint256 fontWeight
    ) external payable returns (uint256);

    function mintPureColorForFontWeight(
        address to,
        uint256 fontWeight,
        bytes16[8] calldata text
    ) external returns (uint256 capsuleId);

    function claim(
        bytes3 color,
        bytes16[8] calldata text,
        uint256 fontWeight
    ) external returns (uint256 capsuleId);

    function withdraw() external;

    function editCapsule(
        uint256 capsuleId,
        bytes16[8] calldata text,
        uint256 fontWeight
    ) external;

    function burn(uint256 capsuleId) external;

    function setCapsulesMetadata(address _capsulesMetadata) external;

    function setCreatorFeeReceiver(address _creatorFeeReceiver) external;

    function setClaimable(address[] calldata receivers, uint256 number)
        external;

    function setRoyalty(uint256 _royalty) external;

    function pause() external;

    function unpause() external;
}
