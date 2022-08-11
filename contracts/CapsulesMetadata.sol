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

struct SvgProps {
    // Capsule color formatted as hex color code
    bytes hexColor;
    // ID for row dots element
    bytes rowId;
    // ID for text-height row dots element
    bytes textRowId;
    // Number of non-empty lines in Capsule text
    uint256 linesCount;
    // Character length of the longest line of text
    uint256 charWidth;
    // Width of the text area in dots
    uint256 textAreaWidthDots;
    // Height of the text area in dots
    uint256 textAreaHeightDots;
    // Square size of the entire svg in dots
    uint256 squareSizeDots;
}

contract CapsulesMetadata is Ownable, ICapsulesMetadata {
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
        string memory isPureText = "no";
        string memory isLockedText = "no";
        if (capsule.isPure) isPureText = "yes";
        if (capsule.isLocked) isLockedText = "yes";

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
                            isPureText,
                            '}, {"locked": "',
                            isLockedText,
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

        SvgProps memory props = _svgPropsOf(capsule);

        bytes memory defs;
        {
            // Define reusable <g> elements to minimize overall SVG size
            bytes
                memory dots1x12 = '<g id="dots1x12"><circle cx="2" cy="2" r="1.5"></circle><circle cx="2" cy="6" r="1.5"></circle><circle cx="2" cy="10" r="1.5"></circle><circle cx="2" cy="14" r="1.5"></circle><circle cx="2" cy="18" r="1.5"></circle><circle cx="2" cy="22" r="1.5"></circle><circle cx="2" cy="26" r="1.5"></circle><circle cx="2" cy="30" r="1.5"></circle><circle cx="2" cy="34" r="1.5"></circle><circle cx="2" cy="38" r="1.5"></circle><circle cx="2" cy="42" r="1.5"></circle><circle cx="2" cy="46" r="1.5"></circle></g>';

            // <g> row of dots 1 dot high that spans entire canvas width
            bytes memory rowDots;
            rowDots = abi.encodePacked('<g id="', props.rowId, '">');
            for (uint256 i; i < props.textAreaWidthDots; i++) {
                rowDots = abi.encodePacked(
                    rowDots,
                    '<circle cx="',
                    Strings.toString(dotSize * i + 2),
                    '" cy="2" r="1.5"></circle>'
                );
            }
            rowDots = abi.encodePacked(rowDots, "</g>");

            // <g> row of dots with text height that spans entire canvas width
            bytes memory textRowDots;
            textRowDots = abi.encodePacked('<g id="', props.textRowId, '">');
            for (uint256 i; i < props.textAreaWidthDots; i++) {
                textRowDots = abi.encodePacked(
                    textRowDots,
                    '<use href="#dots1x12" transform="translate(',
                    Strings.toString(dotSize * i),
                    ')"></use>'
                );
            }
            textRowDots = abi.encodePacked(textRowDots, "</g>");

            defs = abi.encodePacked(dots1x12, rowDots, textRowDots);
        }

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
                ITypeface(capsulesTypeface).fontSrc(
                    Font({weight: capsule.fontWeight, style: "normal"})
                ),
                ') format("opentype")}</style>'
            );
        }

        bytes memory dotArea;
        {
            // Create background of dots as <g> group using <use> elements
            dotArea = abi.encodePacked('<g fill="#', props.hexColor, '"');
            // If square image, translate dots to center of square
            if (square) {
                dotArea = abi.encodePacked(
                    dotArea,
                    ' transform="translate(',
                    Strings.toString(
                        ((props.squareSizeDots - props.textAreaWidthDots) / 2) *
                            dotSize
                    ),
                    " ",
                    Strings.toString(
                        ((props.squareSizeDots - props.textAreaHeightDots) /
                            2) * dotSize
                    ),
                    ')"'
                );
            }
            dotArea = abi.encodePacked(
                dotArea,
                '><g opacity="0.3"><use href="#',
                props.rowId,
                '"></use>'
            );
            for (uint256 i; i < props.linesCount; i++) {
                dotArea = abi.encodePacked(
                    dotArea,
                    '<use href="#',
                    props.textRowId,
                    '" transform="translate(0 ',
                    Strings.toString(48 * i + dotSize),
                    ')"></use>'
                );
            }
            dotArea = abi.encodePacked(
                dotArea,
                '<use href="#',
                props.rowId,
                '" transform="translate(0 ',
                Strings.toString((props.textAreaHeightDots - 1) * dotSize),
                ')"></use></g>'
            );
        }

        // Create <g> group of text elements
        bytes memory texts;
        {
            bytes[8] memory safeText = _htmlSafeText(capsule.text);
            texts = abi.encodePacked(
                '<g transform="translate(10 44)" class="capsules-',
                Strings.toString(capsule.fontWeight),
                '">'
            );
            for (uint256 i = 0; i < props.linesCount; i++) {
                texts = abi.encodePacked(
                    texts,
                    '<text y="',
                    Strings.toString(48 * i),
                    '">',
                    safeText[i],
                    "</text>"
                );
            }
            texts = abi.encodePacked(texts, "</g>");
        }

        dotArea = abi.encodePacked(dotArea, texts, "</g>");

        {
            string memory x;
            string memory y;
            if (square) {
                // If square image, use square viewbox
                x = Strings.toString(props.squareSizeDots * dotSize);
                y = Strings.toString(props.squareSizeDots * dotSize);
            } else {
                // Else fit to text area
                x = Strings.toString(props.textAreaWidthDots * dotSize);
                y = Strings.toString(props.textAreaHeightDots * dotSize);
            }
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
                dotArea,
                "</svg>"
            );
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
    function _isEmptyLine(bytes16 line) internal pure returns (bool) {
        for (uint256 i; i < 16; i++) {
            if (line[i] != 0x00) return false;
        }
        return true;
    }

    /// @notice Returns default text for a Capsule with specified color
    /// @param color Color of Capsule
    /// @return defaultText Default text for Capsule
    function _defaultTextOf(bytes3 color)
        internal
        pure
        returns (bytes16[8] memory defaultText)
    {
        defaultText[0] = bytes16("CAPSULE");
        defaultText[1] = bytes16(
            abi.encodePacked("#", _bytes3ToHexChars(color))
        );
    }

    function _svgPropsOf(Capsule memory capsule)
        internal
        pure
        returns (SvgProps memory props)
    {
        uint256 linesCount;
        for (uint256 i = 8; i > 0; i--) {
            if (!_isEmptyLine(capsule.text[i - 1])) {
                linesCount = i;
                break;
            }
        }
        bytes[8] memory safeText = _htmlSafeText(capsule.text);
        uint256 charWidth;
        for (uint256 i; i < linesCount; i++) {
            if (safeText[i].length > charWidth) {
                charWidth = safeText[i].length;
            }
        }

        bytes memory rowId;
        if (capsule.isLocked) {
            rowId = abi.encodePacked("rowL", Strings.toString(charWidth));
        } else {
            rowId = abi.encodePacked("row", Strings.toString(charWidth));
        }

        // Width of the text area in dots
        uint256 textAreaWidthDots = charWidth * 5 + (charWidth - 1) + 6;
        // Height of the text area in dots
        uint256 textAreaHeightDots = linesCount * 12 + 2;
        // Square size of the entire svg in dots
        uint256 squareSizeDots;
        if (textAreaHeightDots >= textAreaWidthDots) {
            squareSizeDots = textAreaHeightDots + 2;
        } else {
            squareSizeDots = textAreaWidthDots + 2;
        }

        props = SvgProps({
            hexColor: _bytes3ToHexChars(capsule.color),
            rowId: rowId,
            textRowId: abi.encodePacked("textRow", Strings.toString(charWidth)),
            linesCount: linesCount,
            charWidth: charWidth,
            textAreaWidthDots: textAreaWidthDots,
            textAreaHeightDots: textAreaHeightDots,
            squareSizeDots: squareSizeDots
        });
    }

    /// @notice Check if all lines of text are empty
    /// @dev Returns true if every byte of text is 0x00
    function _isEmptyText(bytes16[8] memory text) internal pure returns (bool) {
        for (uint256 i; i < 8; i++) {
            if (!_isEmptyLine(text[i])) return false;
        }

        return true;
    }

    /// @notice Returns html-safe version of text
    /// @dev Iterates through bytes of each line in `text` and replaces each byte as needed
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
