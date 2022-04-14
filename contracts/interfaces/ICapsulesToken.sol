// SPDX-License-Identifier: GPL-3.0

/// @title Interface for Capsules Token

pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ICapsulesToken is IERC721Enumerable {
    event CapsuleMinted(address to, uint256 id, string color);
    event CapsuleClaimed(address to, uint256 id, string color);
    event SetCreatorFeeReceiver(address addresses);
    event SetFriend(address friend, uint256 number);
    event SetText(uint256 id, bytes16[8] text);
    event SetTextEditFee(uint256 fee);
    event Withdraw(address to, uint256 amount);
    event WithdrawCreatorFee(address to, uint256 amount);

    function defaultImageOf(uint256 capsuleId)
        external
        view
        returns (string memory);

    function imageOf(uint256 capsuleId, bytes16[8] memory text)
        external
        view
        returns (string memory);

    function tokenURI(uint256 capsuleId) external view returns (string memory);

    function tokensOfOwner(address) external view returns (uint256[] memory);

    function setText(uint256 capsuleId, bytes16[8] calldata text)
        external
        payable;

    function mint(bytes3 color, bytes16[8] calldata text)
        external
        payable
        returns (uint256);

    function mintAuctionColor() external returns (uint256);

    function burn(uint256 capsuleId) external;

    function withdrawCreatorFee() external;

    function withdraw(uint256 amount) external;

    function setTextEditFee(uint256 _textEditFee) external;

    function pause() external;

    function unpause() external;
}
