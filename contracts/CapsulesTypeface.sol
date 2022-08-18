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
    ) Typeface("Capsules") {
        _setFontSrcHash(fonts, hashes);

        capsulesToken = ICapsulesToken(_capsulesToken);
    }

    /// @notice Returns true if byte is supported by this typeface
    function isAllowedChar(bytes4 b) external pure returns (bool) {
        // TODO
        return true;
        // All basic Latin letters, digits, symbols, punctuation
        // return b >= 0x00000020 && b <= 0x0000007E;
    }

    /// @notice Mint pure color Capsule token to caller when caller sets fontSrc
    function afterSetSource(Font memory font, bytes memory)
        internal
        override(Typeface)
    {
        capsulesToken.mintPureColorForFontWeight(msg.sender, font.weight);
    }
}
