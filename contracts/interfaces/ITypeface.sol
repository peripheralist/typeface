// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct Font {
    uint256 weight;
    string style;
}

interface ITypeface {
    event SetSource(Font font, bytes source);

    event SetSourceHash(Font font, bytes32 sourceHash);

    /**
     * @notice Returns the typeface name.
     */
    function name() external view returns (string memory);

    /**
     * @notice Return true if char is supported by font.
     */
    function isAllowedChar(bytes4 char) external view returns (bool);

    /**
     * @notice Return source bytes for Font.
     */
    function sourceOf(Font memory font) external view returns (bytes memory);

    /**
     * @notice Return source bytes for Font.
     */
    function hasSource(Font memory font) external view returns (bool);

    /**
     * @notice Sets the source bytes for a font
     */
    function setFontSrc(Font memory font, bytes memory src) external;
}
