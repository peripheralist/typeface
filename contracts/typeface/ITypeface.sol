// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IFont.sol";

interface ITypeface {
    /**
     * @dev Returns the typeface name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Return true if byte is supported by font.
     */
    function isAllowedByte(bytes1 b) external view returns (bool);

    /**
     * @dev Return font src from mapping
     */
    function fontSrc(Font memory font) external view returns (bytes memory);
}
