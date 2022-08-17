// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ITypeface.sol";

abstract contract Typeface is ITypeface {
    /// Mapping of weight => style => font source data as bytes.
    mapping(uint256 => mapping(string => bytes)) private _source;

    /// Mapping of weight => style => keccack256 hash of font source data as bytes.
    mapping(uint256 => mapping(string => bytes32)) private _sourceHash;

    /// Mapping of weight => style => true if font source has been stored.
    mapping(uint256 => mapping(string => bool)) private _hasSource;

    /// Typeface name
    string private _name;

    /// @notice Return typeface name.
    /// @return name of typeface
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /// @notice Return source bytes for font.
    /// @return source Font data as bytes
    function sourceOf(Font memory font)
        public
        view
        virtual
        returns (bytes memory)
    {
        return _source[font.weight][font.style];
    }

    /// @notice Return source bytes for font.
    /// @return source Font data as bytes
    function hasSource(Font memory font) public view virtual returns (bool) {
        return _hasSource[font.weight][font.style];
    }

    /// @notice Return hash of source bytes for font.
    /// @return _hash hash of source bytes for font
    function sourceHash(Font memory font)
        public
        view
        virtual
        returns (bytes32)
    {
        return _sourceHash[font.weight][font.style];
    }

    /// @notice Sets source bytes for Font.
    ///  @dev The keccack256 hash of the source must equal the sourceHash of the font.
    ///  @param font Font to set source for
    ///  @param source Font data as bytes
    function setFontSrc(Font memory font, bytes memory source) public {
        require(
            _hasSource[font.weight][font.style] == false,
            "Typeface: font source already exists"
        );

        require(
            keccak256(source) == _sourceHash[font.weight][font.style],
            "Typeface: Invalid font"
        );

        beforeSetSource(font, source);

        _source[font.weight][font.style] = source;
        _hasSource[font.weight][font.style] = true;

        emit SetSource(font, source);

        afterSetSource(font, source);
    }

    /// @notice Sets hash of source data for each font in a list.
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
            _sourceHash[fonts[i].weight][fonts[i].style] = hashes[i];

            emit SetSourceHash(fonts[i], hashes[i]);
        }
    }

    constructor(string memory name_) {
        _name = name_;
    }

    /// @notice Function called before setFontSrc() is called.
    function beforeSetSource(Font memory font, bytes memory src)
        internal
        virtual
    {}

    /// @notice Function called after setFontSrc() is called.
    function afterSetSource(Font memory font, bytes memory src)
        internal
        virtual
    {}
}
