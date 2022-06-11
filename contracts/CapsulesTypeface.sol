// SPDX-License-Identifier: GPL-3.0

/// @title Capsules Typeface

pragma solidity ^0.8.0;

import "./interfaces/ICapsulesToken.sol";
import "./Typeface.sol";

contract CapsulesTypeface is Typeface {
    /// Address of Capsules Token contract
    ICapsulesToken public immutable capsulesToken;

    constructor(
        Font[] memory fonts,
        bytes32[] memory hashes,
        address _capsulesToken
    ) Typeface("Capsules", _capsulesToken) {
        setFontSrcHash(fonts, hashes);

        capsulesToken = ICapsulesToken(_capsulesToken);
    }

    /// @notice Returns true if byte is supported by this typeface
    function isAllowedByte(bytes1 b) external pure returns (bool) {
        // TODO
        // All basic Latin letters, digits, symbols, punctuation
        return b >= 0x20 && b <= 0x7E;
    }

    /// @notice Mint pure color Capsule token to caller when caller sets fontSrc
    function afterSetFontSrc(Font memory font, bytes memory)
        internal
        override(Typeface)
    {
        // Empty text
        bytes16[8] memory text;

        capsulesToken.mintPureColorForFontWeight(msg.sender, font.weight, text);
    }
}
