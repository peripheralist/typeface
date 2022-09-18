// SPDX-License-Identifier: GPL-3.0

/**
  @title ASCIITypeface
  @author peri
  @notice Typeface contract implementation for storing a typeface with characters that require only 1 byte to encode.
 */

pragma solidity ^0.8.0;

import "../TypefaceExpandable.sol";

contract TestTypefaceExpandable is TypefaceExpandable {
    /// For testing
    event BeforeSetSource();

    /// For testing
    event AfterSetSource();

    constructor(
        Font[] memory fonts,
        bytes32[] memory hashes,
        address donationAddress,
        address operator
    ) TypefaceExpandable("TestTypeface", donationAddress, operator) {
        _setSourceHashes(fonts, hashes);
    }

    function supportsCodePoint(bytes3 cp) external pure returns (bool) {
        return cp >= 0x000020 && cp <= 0x00007A;
    }

    function _beforeSetSource(Font calldata, bytes calldata) internal override {
        emit BeforeSetSource();
    }

    function _afterSetSource(Font calldata, bytes calldata) internal override {
        emit AfterSetSource();
    }
}
