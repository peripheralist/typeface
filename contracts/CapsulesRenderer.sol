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
import "./interfaces/ICapsulesRenderer.sol";
import "./utils/Base64.sol";

struct SvgSpecs {
    // Capsule color formatted as hex color code
    bytes hexColor;
    // ID for row elements used on top and bottom edges of svg.
    bytes edgeRowId;
    // ID for row elements placed behind text rows.
    bytes textRowId;
    // Number of non-empty lines in Capsule text. Only trailing empty lines are excluded.
    uint256 linesCount;
    // Number of characters in the longest line of text.
    uint256 charWidth;
    // Width of the text area (in dots).
    uint256 textAreaWidthDots;
    // Height of the text area (in dots).
    uint256 textAreaHeightDots;
}

contract CapsulesRenderer is Ownable, ICapsulesRenderer {
    /// Address of CapsulesTypeface contract
    address public immutable capsulesTypeface;

    constructor(address _capsulesTypeface) {
        capsulesTypeface = _capsulesTypeface;
    }

    function tokenUri(Capsule memory capsule)
        external
        view
        returns (string memory)
    {
        string memory pureText = "no";
        string memory lockedText = "no";
        if (capsule.isPure) pureText = "yes";
        if (capsule.isLocked) lockedText = "yes";

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        abi.encodePacked(
                            '{"name": "Capsule ',
                            Strings.toString(capsule.id),
                            '", "description": "7,957 tokens with unique colors and editable text rendered on-chain. 7 pure colors are reserved for wallets that pay gas to store one of the 7 Capsules font weights in the CapsulesTypeface contract.", "image": "',
                            svgOf(capsule, true),
                            '", "attributes": [{"trait_type": "Color", "value": "#',
                            _bytes3ToHexChars(capsule.color),
                            '"}, {"pure": "',
                            pureText,
                            '}, {"locked": "',
                            lockedText,
                            '"}]}'
                        )
                    )
                )
            );
    }

    /// @notice Return Base64-encoded SVG for Capsule
    /// @param capsule Capsule to return image for
    /// @param square Fit image to square with content centered
    /// @return base64Svg Base64-encoded SVG for Capsule
    function svgOf(Capsule memory capsule, bool square)
        public
        view
        returns (string memory base64Svg)
    {
        uint256 dotSize = 4;

        // If text is not set, use default text
        if (_isEmptyText(capsule.text)) {
            capsule = Capsule({
                text: _defaultTextOf(capsule.color),
                id: capsule.id,
                color: capsule.color,
                fontWeight: capsule.fontWeight,
                isPure: capsule.isPure,
                isLocked: capsule.isLocked
            });
        }

        SvgSpecs memory specs = _svgSpecsOf(capsule);

        // Define reusable <g> elements to minimize overall SVG size
        bytes memory defs;
        {
            bytes
                memory dots1x12 = '<g id="dots1x12"><circle cx="2" cy="2" r="1.5"></circle><circle cx="2" cy="6" r="1.5"></circle><circle cx="2" cy="10" r="1.5"></circle><circle cx="2" cy="14" r="1.5"></circle><circle cx="2" cy="18" r="1.5"></circle><circle cx="2" cy="22" r="1.5"></circle><circle cx="2" cy="26" r="1.5"></circle><circle cx="2" cy="30" r="1.5"></circle><circle cx="2" cy="34" r="1.5"></circle><circle cx="2" cy="38" r="1.5"></circle><circle cx="2" cy="42" r="1.5"></circle><circle cx="2" cy="46" r="1.5"></circle></g>';

            // <g> row of dots 1 dot high that spans entire canvas width
            bytes memory edgeRowDots;
            edgeRowDots = abi.encodePacked('<g id="', specs.edgeRowId, '">');
            for (uint256 i; i < specs.textAreaWidthDots; i++) {
                edgeRowDots = abi.encodePacked(
                    edgeRowDots,
                    '<circle cx="',
                    Strings.toString(dotSize * i + 2),
                    '" cy="2" r="1.5"></circle>'
                );
            }
            edgeRowDots = abi.encodePacked(edgeRowDots, "</g>");

            // <g> row of dots with text height that spans entire canvas width
            bytes memory textRowDots;
            textRowDots = abi.encodePacked('<g id="', specs.textRowId, '">');
            for (uint256 i; i < specs.textAreaWidthDots; i++) {
                textRowDots = abi.encodePacked(
                    textRowDots,
                    '<use href="#dots1x12" transform="translate(',
                    Strings.toString(dotSize * i),
                    ')"></use>'
                );
            }
            textRowDots = abi.encodePacked(textRowDots, "</g>");

            defs = abi.encodePacked(dots1x12, edgeRowDots, textRowDots);
        }

        // Define <style> for svg element
        bytes memory style;
        {
            style = abi.encodePacked(
                "<style>.capsules-",
                Strings.toString(capsule.fontWeight),
                "{ font-size: 40px; white-space: pre; font-family: Capsules-",
                Strings.toString(capsule.fontWeight),
                ' } @font-face { font-family: "Capsules-',
                Strings.toString(capsule.fontWeight),
                '"; src: url(data:font/truetype;charset=utf-8;base64,',
                ITypeface(capsulesTypeface).sourceOf(
                    Font({weight: capsule.fontWeight, style: "normal"})
                ),
                ') format("opentype")}</style>'
            );
        }

        // Content area group will contain dot background and text.
        bytes memory contentArea;
        {
            // Create <g> element and define color of dots and text.
            contentArea = abi.encodePacked('<g fill="#', specs.hexColor, '"');

            // If square image, translate contentArea group to center of svg viewbox
            if (square) {
                // Square size of the entire svg (in dots) equal to longest edge, including padding of 2 dots
                uint256 squareSizeDots = 2;
                if (specs.textAreaHeightDots >= specs.textAreaWidthDots) {
                    squareSizeDots += specs.textAreaHeightDots;
                } else {
                    squareSizeDots += specs.textAreaWidthDots;
                }

                contentArea = abi.encodePacked(
                    contentArea,
                    ' transform="translate(',
                    Strings.toString(
                        ((squareSizeDots - specs.textAreaWidthDots) / 2) *
                            dotSize
                    ),
                    " ",
                    Strings.toString(
                        ((squareSizeDots - specs.textAreaHeightDots) / 2) *
                            dotSize
                    ),
                    ')"'
                );
            }

            // Add dots by tiling edge row and text row elements defined in `defs`.

            // Add top edge row element
            contentArea = abi.encodePacked(
                contentArea,
                '><g opacity="0.3"><use href="#',
                specs.edgeRowId,
                '"></use>'
            );

            // Add a text row element for each line of text
            for (uint256 i; i < specs.linesCount; i++) {
                contentArea = abi.encodePacked(
                    contentArea,
                    '<use href="#',
                    specs.textRowId,
                    '" transform="translate(0 ',
                    Strings.toString(48 * i + dotSize),
                    ')"></use>'
                );
            }

            // Add bottom edge row element and close <g> group element
            contentArea = abi.encodePacked(
                contentArea,
                '<use href="#',
                specs.edgeRowId,
                '" transform="translate(0 ',
                Strings.toString((specs.textAreaHeightDots - 1) * dotSize),
                ')"></use></g>'
            );
        }

        // Create <g> group of text elements
        bytes memory texts;
        {
            // Create <g> element for texts and position using translate
            texts = '<g transform="translate(10 44)">';

            // Add a <text> element for each line of text, excluding trailing empty lines.
            // Each <text> has its own Y position.
            // Setting class on individual <text> elements adds css specificity and helps ensure styles are not overwritten by external stylesheets.
            for (uint256 i; i < specs.linesCount; i++) {
                texts = abi.encodePacked(
                    texts,
                    '<text y="',
                    Strings.toString(48 * i),
                    '" class="capsules-',
                    Strings.toString(capsule.fontWeight),
                    '">',
                    htmlSafeLine(capsule.text[i]),
                    "</text>"
                );
            }

            // Close <g> texts group.
            texts = abi.encodePacked(texts, "</g>");
        }

        // Add texts to content area group and close <g> group.
        contentArea = abi.encodePacked(contentArea, texts, "</g>");

        {
            string memory x;
            string memory y;
            if (square) {
                // Square size of the entire svg (in dots) equal to longest edge, including padding of 2 dots
                uint256 squareSizeDots = 2;
                if (specs.textAreaHeightDots >= specs.textAreaWidthDots) {
                    squareSizeDots += specs.textAreaHeightDots;
                } else {
                    squareSizeDots += specs.textAreaWidthDots;
                }

                // If square image, use square viewbox
                x = Strings.toString(squareSizeDots * dotSize);
                y = Strings.toString(squareSizeDots * dotSize);
            } else {
                // Else fit to text area
                x = Strings.toString(specs.textAreaWidthDots * dotSize);
                y = Strings.toString(specs.textAreaHeightDots * dotSize);
            }

            // Construct parent svg element with defs, style, and content area groups.
            bytes memory svg = abi.encodePacked(
                '<svg viewBox="0 0 ',
                x,
                " ",
                y,
                '" preserveAspectRatio="xMidYMid meet" xmlns="http://www.w3.org/2000/svg"><defs>',
                defs,
                "</defs>",
                style,
                '<rect x="0" y="0" width="100%" height="100%" fill="#000"></rect>',
                contentArea,
                "</svg>"
            );

            // Base64 encode the svg data with prefix
            base64Svg = string(
                abi.encodePacked(
                    "data:image/svg+xml;base64,",
                    Base64.encode(svg)
                )
            );
        }
    }

    /// @notice Check if line is empty
    /// @dev Returns true if every byte of text is 0x00
    /// @param line line to check if empty
    /// @return true if line is empty
    function _isEmptyLine(bytes4[16] memory line) internal pure returns (bool) {
        for (uint256 i; i < 16; i++) {
            if (line[i] != bytes4(0)) return false;
        }
        return true;
    }

    /// @notice Returns default text for a Capsule with specified color
    /// @param color Color of Capsule
    /// @return defaultText Default text for Capsule
    function _defaultTextOf(bytes3 color)
        internal
        pure
        returns (bytes4[16][8] memory defaultText)
    {
        defaultText[0][0] = bytes4("C");
        defaultText[0][1] = bytes4("A");
        defaultText[0][2] = bytes4("P");
        defaultText[0][3] = bytes4("S");
        defaultText[0][4] = bytes4("U");
        defaultText[0][5] = bytes4("L");
        defaultText[0][6] = bytes4("E");

        bytes memory _color = _bytes3ToHexChars(color);
        defaultText[1][0] = bytes4("#");
        defaultText[1][1] = bytes4(_color[0]);
        defaultText[1][2] = bytes4(_color[1]);
        defaultText[1][3] = bytes4(_color[2]);
        defaultText[1][4] = bytes4(_color[3]);
        defaultText[1][5] = bytes4(_color[4]);
        defaultText[1][6] = bytes4(_color[5]);
    }

    /// @notice Calculate specs used to build SVG for capsule
    /// @param capsule Capsule to calculate specs for
    /// @return specs SVG specs calculated for Capsule
    function _svgSpecsOf(Capsule memory capsule)
        internal
        pure
        returns (SvgSpecs memory specs)
    {
        // Calculate number of lines of Capsule text to render. Only trailing empty lines are excluded.
        uint256 linesCount;
        for (uint256 i = 8; i > 0; i--) {
            if (!_isEmptyLine(capsule.text[i - 1])) {
                linesCount = i;
                break;
            }
        }

        // Calculate the width of the Capsule text in characters. Equal to the number of non-empty characters in the longest line.
        uint256 charWidth;
        for (uint256 i; i < linesCount; i++) {
            // Reverse iterate over line
            for (uint256 j = 16; j > 0; j--) {
                if (capsule.text[i][j - 1] != bytes4(0) && j > charWidth) {
                    charWidth = j;
                }
            }
        }

        // Define the id of the svg row element.
        bytes memory edgeRowId;
        if (capsule.isLocked) {
            edgeRowId = abi.encodePacked("rowL", Strings.toString(charWidth));
        } else {
            edgeRowId = abi.encodePacked("row", Strings.toString(charWidth));
        }

        // Width of the text area (in dots)
        uint256 textAreaWidthDots = charWidth * 5 + (charWidth - 1) + 6;
        // Height of the text area (in dots)
        uint256 textAreaHeightDots = linesCount * 12 + 2;

        specs = SvgSpecs({
            hexColor: _bytes3ToHexChars(capsule.color),
            edgeRowId: edgeRowId,
            textRowId: abi.encodePacked("textRow", Strings.toString(charWidth)),
            linesCount: linesCount,
            charWidth: charWidth,
            textAreaWidthDots: textAreaWidthDots,
            textAreaHeightDots: textAreaHeightDots
        });
    }

    /// @notice Check if all lines of text are empty
    /// @dev Returns true if every line of text is empty
    /// @param text Text to check if empty
    /// @return true if text is empty
    function _isEmptyText(bytes4[16][8] memory text)
        internal
        pure
        returns (bool)
    {
        for (uint256 i; i < 8; i++) {
            if (!_isEmptyLine(text[i])) return false;
        }
        return true;
    }

    /// @notice Returns html-safe version of text.
    /// @param text Text to render safe.
    /// @return safeText Text string array that can be safely rendered in html.
    function htmlSafeText(bytes4[16][8] memory text)
        external
        pure
        returns (string[8] memory safeText)
    {
        for (uint256 i; i < 8; i++) {
            safeText[i] = htmlSafeLine(text[i]);
        }
    }

    /// @notice Returns html-safe version of a line of text
    /// @dev Iterates through each byte in line of text and replaces each byte as needed to create a string that will render in html without issue. Ensures that no illegal characters or 0x00 bytes remain.
    /// @param line Line of text to render safe.
    /// @return safeLine Text string that can be safely rendered in html.
    function htmlSafeLine(bytes4[16] memory line)
        internal
        pure
        returns (string memory safeLine)
    {
        // Build bytes in reverse to allow trimming trailing whitespace
        for (uint256 i = 16; i > 0; i--) {
            bytes4 char = line[i - 1];

            // 0x0 bytes should not be rendered.
            if (char == bytes4(0)) continue;

            // Some bytes may not render properly in SVG text, so we replace them with their matching "html name code".
            if (char == 0x0000003c) {
                // Replace `<`
                safeLine = string.concat("&lt;", safeLine);
            } else if (char == 0x0000003E) {
                // Replace `>`
                safeLine = string.concat("&gt;", safeLine);
            } else if (char == 0x00000026) {
                // Replace `&`
                safeLine = string.concat("&amp;", safeLine);
            } else {
                // Add bytes4 character while removing individual 0x0 bytes, which cannot be rendered.
                for (uint256 j = 4; j > 0; j--) {
                    if (char[j - 1] != bytes1(0)) {
                        safeLine = string(
                            abi.encodePacked(char[j - 1], safeLine)
                        );
                    }
                }
            }
        }
    }

    /// @notice Format bytes3 type to 6 hexadecimal ascii bytes
    /// @param b bytes3 value to convert to hex characters
    /// @return o hex character bytes
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
    /// @param i uint8 value to convert to ascii byte
    /// @return b ascii byte
    function _uint8toByte(uint8 i) internal pure returns (bytes1 b) {
        uint8 _i = (i > 9)
            ? (i + 87) // ascii a-f
            : (i + 48); // ascii 0-9

        b = bytes1(_i);
    }
}
