// SPDX-License-Identifier: GPL-3.0

/// @title Interface for Capsules Metadata

pragma solidity ^0.8.13;

import "./ICapsulesToken.sol";

interface ICapsulesMetadata {
    function tokenUri(Capsule memory capsule)
        external
        view
        returns (string memory);

    function svgOf(Capsule memory capsule, bool square)
        external
        view
        returns (string memory);
}
