// SPDX-License-Identifier: GPL-3.0

/// @title Capsules Typeface

pragma solidity ^0.8.0;

import "./Typeface.sol";

contract CapsulesTypeface is Typeface {
    function isAllowedByte(bytes1 b) external pure returns (bool) {
        // All basic Latin letters, digits, symbols, punctuation
        return b >= 0x20 && b <= 0x7E;
    }

    constructor(Font[] memory fonts, bytes32[] memory hashes)
        Typeface("Capsules")
    {
        setFontSrcHash(fonts, hashes);
    }
}
