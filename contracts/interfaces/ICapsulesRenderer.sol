// SPDX-License-Identifier: GPL-3.0

/// @title Interface for Capsules Renderer

pragma solidity ^0.8.13;

import "./ICapsulesToken.sol";

interface ICapsulesRenderer {
    function tokenUri(Capsule memory capsule)
        external
        view
        returns (string memory);

    function svgOf(Capsule memory capsule, bool square)
        external
        view
        returns (string memory);

    function htmlSafeText(bytes4[16][8] memory line)
        external
        pure
        returns (string[8] memory safeText);
}
