// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITypeface {
    struct Font {
        uint256 weight;
        string style;
    }

    event SetFontSrc(Font indexed font);

    event SetFontSrcHash(Font indexed font, bytes32 indexed _hash);

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
