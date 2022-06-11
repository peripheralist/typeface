// SPDX-License-Identifier: GPL-3.0

/// @title Capsules Token
/// @author peri
/// @notice Each Capsule token has a unique color and a custom text rendered as a SVG. The text for a Capsule can be updated at any time by its owner.
/// @dev bytes3 type is used to store the 3 bytes of the rgb hex-encoded color that is unique to each capsule.

pragma solidity 0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/ITypeface.sol";
import "./interfaces/ICapsulesToken.sol";
import "./interfaces/ICapsulesMetadata.sol";
import "./utils/Base64.sol";

contract CapsulesMetadata is Ownable, ICapsulesMetadata {
    /// Address of CapsulesToken contract
    address public immutable capsulesToken;

    /// Address of CapsulesTypeface contract
    address public immutable capsulesTypeface;

    constructor(address _capsulesToken, address _capsulesTypeface) {
        capsulesToken = _capsulesToken;
        capsulesTypeface = _capsulesTypeface;
    }

    function tokenUri(Capsule memory capsule)
        external
        view
        returns (string memory)
    {
        string memory image;

        // If text is not set, use default image
        if (_isEmptyText(capsule.text)) {
            image = defaultImageOf(capsule);
        } else {
            image = imageFor(capsule);
        }

        bytes memory json = abi.encodePacked(
            '{"name": "Capsule ',
            Strings.toString(capsule.id),
            '", "description": "7,957 tokens with unique colors and editable text rendered on-chain. 7 pure colors are reserved for wallets that pay gas to store one of the 7 Capsules font weights in the CapsulesTypeface contract.", "image": "',
            image,
            '", "attributes": [{"trait_type": "Color", "value": "#',
            _bytes3ToHexChars(capsule.color),
            '"}, {"pure": "',
            ICapsulesToken(capsulesToken).isPureColor(capsule.color),
            "}]}"
        );

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(json)
                )
            );
    }

    /// @notice Return base64 encoded SVG for Capsule
    /// @param capsule Capsule to return image for
    /// @return image image for Capsule
    function imageFor(Capsule memory capsule)
        internal
        view
        returns (string memory image)
    {
        // Count the number of lines that are not empty. Only these lines will be rendered
        uint256 linesCount;
        {
            for (uint256 i = 8; i > 0; i--) {
                if (!_isEmptyLine(capsule.text[i - 1])) {
                    linesCount = i;
                    break;
                }
            }
        }

        bytes[8] memory safeText = _htmlSafeText(capsule.text);

        // Count the character length of the longest line of text
        uint256 longestLine;
        for (uint256 i; i < linesCount; i++) {
            if (safeText[i].length > longestLine) {
                longestLine = safeText[i].length;
            }
        }

        // Width of the canvas in dots
        uint256 canvasWidthDots = longestLine * 5 + (longestLine - 1) + 6;
        // Height of the canvas in dots
        uint256 canvasHeightDots = linesCount * 12 + 2;

        bytes memory rowId = abi.encodePacked(
            "row",
            Strings.toString(longestLine)
        );
        bytes memory textRowId = abi.encodePacked(
            "textRow",
            Strings.toString(longestLine)
        );

        bytes memory hexColor = _bytes3ToHexChars(capsule.color);

        string memory _fontWeight = Strings.toString(capsule.fontWeight);

        bytes memory defs;
        {
            // Reuse <g> elements instead of individual <circle> elements to minimize overall SVG size
            bytes
                memory dots1x12 = '<g id="dots1x12"><circle cx="2" cy="2" r="1.5"></circle><circle cx="2" cy="6" r="1.5"></circle><circle cx="2" cy="10" r="1.5"></circle><circle cx="2" cy="14" r="1.5"></circle><circle cx="2" cy="18" r="1.5"></circle><circle cx="2" cy="22" r="1.5"></circle><circle cx="2" cy="26" r="1.5"></circle><circle cx="2" cy="30" r="1.5"></circle><circle cx="2" cy="34" r="1.5"></circle><circle cx="2" cy="38" r="1.5"></circle><circle cx="2" cy="42" r="1.5"></circle><circle cx="2" cy="46" r="1.5"></circle></g>';

            // <g> row of dots 1 dot high that spans entire canvas width
            bytes memory rowDots;
            {
                rowDots = abi.encodePacked('<g id="', rowId, '">');
                for (uint256 i; i < canvasWidthDots; i++) {
                    rowDots = abi.encodePacked(
                        rowDots,
                        '<circle cx="',
                        Strings.toString(4 * i + 2),
                        '" cy="2" r="1.5"></circle>'
                    );
                }
                rowDots = abi.encodePacked(rowDots, "</g>");
            }

            // <g> row of dots with text height that spans entire canvas width
            bytes memory textRowDots;
            {
                textRowDots = abi.encodePacked('<g id="', textRowId, '">');
                for (uint256 i; i < canvasWidthDots; i++) {
                    textRowDots = abi.encodePacked(
                        textRowDots,
                        '<use href="#dots1x12" transform="translate(',
                        Strings.toString(4 * i),
                        ')"></use>'
                    );
                }
                textRowDots = abi.encodePacked(textRowDots, "</g>");
            }

            defs = abi.encodePacked(dots1x12, rowDots, textRowDots);
        }

        bytes memory style;
        {
            Font memory font = Font({
                weight: capsule.fontWeight,
                style: "normal"
            });
            bytes memory fontSrc = ITypeface(capsulesTypeface).fontSrc(font);
            style = abi.encodePacked(
                '<style>text { font-size: 40px; white-space: pre; } @font-face { font-family: "Capsules-',
                _fontWeight,
                '"; src: url(data:font/truetype;charset=utf-8;base64,',
                fontSrc,
                ') format("opentype")}</style>'
            );
        }

        bytes memory dots;
        {
            // Create background of dots as <g> group using <use> elements
            dots = abi.encodePacked(
                '<g fill="#',
                hexColor,
                '" opacity="0.3"><use href="#',
                rowId,
                '"></use>'
            );
            for (uint256 i; i < linesCount; i++) {
                dots = abi.encodePacked(
                    dots,
                    '<use href="#',
                    textRowId,
                    '" transform="translate(0 ',
                    Strings.toString(48 * i + 4),
                    ')"></use>'
                );
            }
            dots = abi.encodePacked(
                dots,
                '<use href="#',
                rowId,
                '" transform="translate(0 ',
                Strings.toString((canvasHeightDots - 1) * 4),
                ')"></use></g>'
            );
        }

        // Create <g> group of text elements
        bytes memory texts;
        {
            texts = abi.encodePacked(
                '<g fill="#',
                hexColor,
                '" transform="translate(10 44)">'
            );
            for (uint256 i = 0; i < linesCount; i++) {
                texts = abi.encodePacked(
                    texts,
                    '<text y="',
                    Strings.toString(48 * i),
                    '" font-family="Capsules-',
                    _fontWeight,
                    '">',
                    safeText[i],
                    "</text>"
                );
            }
            texts = abi.encodePacked(texts, "</g>");
        }

        bytes memory svg;
        {
            svg = abi.encodePacked(
                '<svg viewBox="0 0 ',
                Strings.toString(canvasWidthDots * 4),
                " ",
                Strings.toString(canvasHeightDots * 4),
                '" preserveAspectRatio="xMidYMid meet" xmlns="http://www.w3.org/2000/svg"><defs>',
                defs,
                "</defs>",
                style,
                '<rect x="0" y="0" width="100%" height="100%" fill="#000"></rect>',
                dots,
                texts,
                "</svg>"
            );
        }

        image = string(
            abi.encodePacked("data:image/svg+xml;base64,", Base64.encode(svg))
        );
    }

    /// @notice Return placeholder image for a Capsule
    /// @param capsule Capsule to return default image for
    /// @return image default image for Capsule
    function defaultImageOf(Capsule memory capsule)
        internal
        view
        returns (string memory image)
    {
        bytes16[8] memory text;
        text[0] = bytes16("CAPSULE");
        text[1] = bytes16(
            abi.encodePacked("#", _bytes3ToHexChars(capsule.color))
        );

        image = imageFor(
            Capsule({
                text: text,
                id: capsule.id,
                color: capsule.color,
                fontWeight: capsule.fontWeight
            })
        );
    }

    /// @notice Check if line is empty
    /// @dev Returns true if every byte of text is 0x00
    /// @param line text to check if empty
    function _isEmptyLine(bytes16 line) internal pure returns (bool) {
        for (uint256 i; i < 16; i++) {
            if (line[i] != 0x00) return false;
        }

        return true;
    }

    /// @notice Check if text is empty
    /// @dev Returns true if every byte of text is 0x00
    /// @param text text to check if empty
    function _isEmptyText(bytes16[8] memory text) internal pure returns (bool) {
        for (uint256 i; i < 8; i++) {
            if (!_isEmptyLine(text[i])) return false;
        }

        return true;
    }

    /// @notice Returns html-safe version of text
    /// @dev Iterates through bytes of each line in `text` and replaces each byte as needed
    /// @param text text to format
    function _htmlSafeText(bytes16[8] memory text)
        internal
        pure
        returns (bytes[8] memory safeText)
    {
        // Some bytes may not render properly in SVG text, so we replace them with their matching 'html name code'
        for (uint16 i; i < 8; i++) {
            bool shouldTrim = true;

            // Build bytes in reverse to allow trimming trailing whitespace
            for (uint16 j = 16; j > 0; j--) {
                if (text[i][j - 1] != 0x00 && shouldTrim) shouldTrim = false;

                if (text[i][j - 1] == 0x3c) {
                    // Replace `<`
                    safeText[i] = abi.encodePacked("&lt;", safeText[i]);
                } else if (text[i][j - 1] == 0x3E) {
                    // Replace `>`
                    safeText[i] = abi.encodePacked("&gt;", safeText[i]);
                } else if (text[i][j - 1] == 0x26) {
                    // Replace `&`
                    safeText[i] = abi.encodePacked("&amp;", safeText[i]);
                } else if (text[i][j - 1] == 0x00) {
                    // If whitespace has been trimmed, replace `0x00` with space
                    // Else, add nothing
                    if (!shouldTrim) {
                        safeText[i] = abi.encodePacked(
                            bytes1(0x20),
                            safeText[i]
                        );
                    }
                } else {
                    // Add unchanged byte
                    safeText[i] = abi.encodePacked(text[i][j - 1], safeText[i]);
                }
            }
        }
    }

    /// @notice Format bytes3 type to 6 hexadecimal ascii bytes
    function _bytes3ToHexChars(bytes3 b)
        internal
        pure
        returns (bytes memory o)
    {
        uint24 i = uint24(b);
        o = new bytes(6);
        uint24 mask = 0x00000f;
        o[5] = _uint8toByte(uint8(i & mask));
        i = i >> 4;
        o[4] = _uint8toByte(uint8(i & mask));
        i = i >> 4;
        o[3] = _uint8toByte(uint8(i & mask));
        i = i >> 4;
        o[2] = _uint8toByte(uint8(i & mask));
        i = i >> 4;
        o[1] = _uint8toByte(uint8(i & mask));
        i = i >> 4;
        o[0] = _uint8toByte(uint8(i & mask));
    }

    /// @notice Convert uint8 type to ascii byte
    function _uint8toByte(uint8 i) internal pure returns (bytes1 b) {
        uint8 _i = (i > 9)
            ? (i + 87) // ascii a-f
            : (i + 48); // ascii 0-9

        b = bytes1(_i);
    }
}
