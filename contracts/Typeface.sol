// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ITypeface.sol";

abstract contract Typeface is ITypeface {
    /// Mapping of weight => style => font src data as bytes
    mapping(uint256 => mapping(string => bytes)) private _fontSrc;

    /// Mapping of weight => style => keccack256 hash of font src data as bytes
    mapping(uint256 => mapping(string => bytes32)) private _fontSrcHash;

    /// Typeface name
    string private _name;

    /// Address to receive royalties
    address private _royaltyAddress;

    /// @notice Return typeface name.
    /// @return name of typeface
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /// @notice Return royalty address.
    /// @return address to receive royalties
    function royaltyAddress() public view virtual override returns (address) {
        return _royaltyAddress;
    }

    /// @notice Return src bytes for font.
    /// @return src Font data as bytes
    function fontSrc(Font memory font)
        public
        view
        virtual
        returns (bytes memory src)
    {
        src = _fontSrc[font.weight][font.style];
    }

    /// @notice Return hash of src bytes for font.
    /// @return _hash hash of src bytes for font
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
    ///  @param src Font data as bytes
    function setFontSrc(Font memory font, bytes memory src) public {
        require(
            _fontSrc[font.weight][font.style].length == 0,
            "Typeface: font src already exists"
        );

        require(
            keccak256(src) == _fontSrcHash[font.weight][font.style],
            "Typeface: Invalid font"
        );

        beforeSetFontSrc(font, src);

        _fontSrc[font.weight][font.style] = src;

        emit SetFontSrc(font, src);

        afterSetFontSrc(font, src);
    }

    /// @notice Sets hash of src data for each font in a list.
    /// @dev Length of fonts and hashes arrays must be equal. Each hash from hashes array will be set for the font with matching index in the fonts array.
    /// @param fonts Array of fonts to set hashes for
    /// @param hashes Array of hashes to set for fonts
    function setFontSrcHash(Font[] memory fonts, bytes32[] memory hashes)
        internal
    {
        require(
            fonts.length == hashes.length,
            "Typeface: Unequal number of fonts and hashes"
        );

        for (uint256 i; i < fonts.length; i++) {
            _fontSrcHash[fonts[i].weight][fonts[i].style] = hashes[i];

            emit SetFontSrcHash(fonts[i], hashes[i]);
        }
    }

    constructor(string memory name_, address __royaltyAddress) {
        _name = name_;
        _royaltyAddress = __royaltyAddress;
    }

    /// @notice Function called before setFontSrc() is called.
    function beforeSetFontSrc(Font memory font, bytes memory src)
        internal
        virtual
    {}

    /// @notice Function called after setFontSrc() is called.
    function afterSetFontSrc(Font memory font, bytes memory src)
        internal
        virtual
    {}
}
