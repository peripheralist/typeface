// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ITypeface.sol";

abstract contract Typeface is ITypeface {
    /// Mapping of font src by weight => style
    mapping(uint256 => mapping(string => bytes)) private _fontSrc;

    /// Mapping of keccack256 hash of font src by weight => style
    mapping(uint256 => mapping(string => bytes32)) private _fontSrcHash;

    /// Typeface name
    string private _name;

    /// @notice Return typeface name
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /// @notice Return font src from mapping
    function fontSrc(Font memory font)
        public
        view
        virtual
        returns (bytes memory src)
    {
        src = _fontSrc[font.weight][font.style];
    }

    /// @notice Return font src hash from mapping
    function fontSrcHash(Font memory font)
        public
        view
        virtual
        returns (bytes32 _hash)
    {
        _hash = _fontSrcHash[font.weight][font.style];
    }

    /// @notice Sets src bytes for Font.
    ///  @dev The keccack256 hash of the src must equal the fontSrcHash of the font.
    ///  @param font Font to set src for
    ///  @param src Bytes data that represents the font source data
    function setFontSrc(Font memory font, bytes memory src) public {
        require(
            _fontSrc[font.weight][font.style].length == 0,
            "Font already initialized"
        );

        require(
            keccak256(src) == _fontSrcHash[font.weight][font.style],
            "Invalid font"
        );

        _fontSrc[font.weight][font.style] = src;

        emit SetFontSrc(font);
    }

    /// @notice Sets hash of src for Font.
    ///  @dev Length of fonts and hashes arrays must be equal. Each hash from hashes array will be set for the font with matching index in the fonts array.
    ///  @param fonts Array of fonts to set hashes for
    ///  @param hashes Array of hashes to set for fonts
    function setFontSrcHash(Font[] memory fonts, bytes32[] memory hashes)
        internal
    {
        require(
            fonts.length == hashes.length,
            "Unequal number of fonts and hashes"
        );

        for (uint256 i; i < fonts.length; i++) {
            _fontSrcHash[fonts[i].weight][fonts[i].style] = hashes[i];

            emit SetFontSrcHash(fonts[i], hashes[i]);
        }
    }

    constructor(string memory name_) {
        _name = name_;
    }
}
