// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ITypeface.sol";

abstract contract Typeface is ITypeface {
    // Mapping of font src by weight => style
    mapping(uint256 => mapping(bytes32 => bytes)) _fontSrc;

    // Typeface name
    string private _name;

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Return font src from mapping
     */
    function fontSrc(Font memory font)
        public
        view
        virtual
        returns (bytes memory src)
    {
        src = _fontSrc[font.weight][font.style];
        require(src.length > 0, "Missing font");
    }

    /**
     * @dev Initializes the contract by setting a `name` for the typeface.
     */
    constructor(string memory name_) {
        _name = name_;
    }
}
