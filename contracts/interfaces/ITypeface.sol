// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct Font {
    uint256 weight;
    string style;
}

interface ITypeface {
    event SetFontSrc(Font font, bytes src);

    event SetFontSrcHash(Font font, bytes32 _hash);

    /**
     * @notice Returns the typeface name.
     */
    function name() external view returns (string memory);

    /**
     * @notice Return true if byte is supported by font.
     */
    function isAllowedByte(bytes1 b) external view returns (bool);

    /**
     * @notice Return src bytes for Font.
     */
    function fontSrc(Font memory font) external view returns (bytes memory);

    function setFontSrc(Font memory font, bytes memory src) external;
}
