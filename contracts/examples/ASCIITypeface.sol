// SPDX-License-Identifier: GPL-3.0

/**
  @title ASCIITypeface
  @author peri
  @notice Typeface contract implementation for storing a typeface with characters that require only 1 byte to encode.
 */

pragma solidity ^0.8.0;

import "../Typeface.sol";

contract ASCIITypeface is Typeface {
    /// For testing
    event BeforeSetSource();

    /// For testing
    event AfterSetSource();

    constructor(Font[] memory fonts, bytes32[] memory hashes)
        Typeface("ASCIITypeface")
    {
        _setFontSourceHashes(fonts, hashes);
    }

    function isSupportedByte(bytes1 b) external pure override returns (bool) {
        // All basic Latin letters, digits, symbols, punctuation.
        // Note: For testing, this is not necessarily the encoded typeface's actual supported charset.
        return b >= 0x20 && b <= 0x7E;
    }

    function isSupportedBytes4(bytes4 b) external pure override returns (bool) {
        // All basic Latin letters, digits, symbols, punctuation.
        // Note: For testing, this is not necessarily the encoded typeface's actual supported charset.
        return b >= 0x00000020 && b <= 0x0000007E;
    }

    function _beforeSetSource(Font calldata, bytes calldata) internal override {
        emit BeforeSetSource();
    }

    function _afterSetSource(Font calldata, bytes calldata) internal override {
        emit AfterSetSource();
    }
}
