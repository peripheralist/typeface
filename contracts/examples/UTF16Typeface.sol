// SPDX-License-Identifier: GPL-3.0

/**
  @title UTF32Typeface
  @author peri
  @notice Typeface contract implementation for storing a typeface with characters that require more than 1 byte to encode.
 */

pragma solidity ^0.8.0;

import "../Typeface.sol";

contract UTF16Typeface is Typeface {
    constructor(Font[] memory fonts, bytes32[] memory hashes)
        Typeface("UTF32Typeface")
    {
        _setFontSourceHashes(fonts, hashes);
    }

    function isSupportedByte(bytes1 b) external pure override returns (bool) {
        // All basic Latin letters, digits, symbols, punctuation.
        return b >= 0x20 && b <= 0x7E;
    }

    function isSupportedBytes4(bytes4 b) external pure override returns (bool) {
        // All basic Latin letters, digits, symbols, punctuation, plus range of additional characters requiring up to 4 bytes to encode.
        // Note: For testing, this is not necessarily the encoded typeface's actual supported charset.
        return b >= 0x00000020 && b <= 0x00E289A5;
    }
}
