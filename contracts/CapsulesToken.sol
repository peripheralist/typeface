// SPDX-License-Identifier: GPL-3.0

/// @title Capsules Token
/// @author peri
/// @notice Each Capsule token has a unique color and a custom text rendered as a SVG. The text for a Capsule can be updated at any time by its owner.
/// @dev bytes3 type is used to store the 3 bytes of the rgb hex-encoded color that is unique to each capsule.

pragma solidity 0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./ERC721A.sol";
import "./interfaces/ICapsulesToken.sol";
import "./interfaces/ITypeface.sol";
import "./utils/Base64.sol";

contract CapsulesToken is
    ICapsulesToken,
    ERC721A,
    IERC2981,
    Ownable,
    Pausable,
    ReentrancyGuard
{
    /* -------------------------------------------------------------------------- */
    /* -------------------------------- MODIFIERS ------------------------------- */
    /* -------------------------------------------------------------------------- */

    /// @notice Require that the value sent is at least MINT_PRICE
    modifier requireMintPrice() {
        require(
            msg.value >= MINT_PRICE,
            "Ether value sent is below the mint price"
        );
        _;
    }

    /// @notice Require that the text is valid
    modifier onlyValidText(bytes16[8] calldata text) {
        require(_isValidText(text), "Invalid text");
        _;
    }

    /// @notice Require that the text is valid
    modifier onlyValidFontWeight(uint256 fontWeight) {
        require(_isValidFontWeight(fontWeight), "Invalid font weight");
        _;
    }

    /// @notice Require that the color is valid
    modifier onlyValidColor(bytes3 color) {
        require(_isValidColor(color), "Invalid color");
        _;
    }

    /// @notice Require that the color is not reserved
    modifier onlyUnreservedColor(bytes3 color) {
        require(!_isReservedColor(color), "Color reserved");
        _;
    }

    /// @notice Require that the sender is the Capsules Typeface contract
    modifier onlyCapsulesTypeface() {
        require(
            msg.sender == capsulesTypeface,
            "Caller is not the Capsules Typeface"
        );
        _;
    }

    /// @notice Require that the color is valid
    modifier onlyClaimable() {
        require(claimCount[msg.sender] >= 1, "No claimable tokens");
        _;
    }

    /// @notice Require that the color is not minted
    modifier onlyUnmintedColor(bytes3 color) {
        require(tokenOfColor[color] == 0, "Color already minted");
        _;
    }

    /// @notice Require that the sender is the Capsule owner
    modifier onlyCapsuleOwner(uint256 capsuleId) {
        require(ownerOf(capsuleId) == msg.sender, "Capsule not owned");
        _;
    }

    /* -------------------------------------------------------------------------- */
    /* ------------------------------- CONSTRUCTOR ------------------------------ */
    /* -------------------------------------------------------------------------- */

    constructor(
        address _capsulesTypeface,
        address _creatorFeeReceiver,
        bytes3[] memory _reservedColors,
        uint256 _royalty
    ) ERC721A("Capsules", "CAPS") {
        capsulesTypeface = _capsulesTypeface;
        creatorFeeReceiver = _creatorFeeReceiver;
        reservedColors = _reservedColors;
        emit SetReservedColors(_reservedColors);
        royalty = _royalty;

        _pause();
    }

    /* -------------------------------------------------------------------------- */
    /* -------------------------------- VARIABLES ------------------------------- */
    /* -------------------------------------------------------------------------- */

    /// Price to mint a Capsule
    uint256 public constant MINT_PRICE = 2e16; // 0.02 ETH

    /// Mapping of addresses to number of tokens that can be claimed
    mapping(address => uint256) public claimCount;

    /// Capsules typeface address
    address public immutable capsulesTypeface;

    /// Color for a token id
    mapping(uint256 => bytes3) public colorOf;

    /// Token id for a color
    mapping(bytes3 => uint256) public tokenOfColor;

    /// Text of a token id
    mapping(uint256 => bytes16[8]) public textOf;

    /// Font weight of a token id
    mapping(uint256 => uint256) public fontWeightOf;

    /// Array of reserved colors
    bytes3[] reservedColors;

    /// Address to receive fees
    address public creatorFeeReceiver;

    /// Royalty amount out of 1000
    uint256 public royalty;

    /* -------------------------------------------------------------------------- */
    /* --------------------------- EXTERNAL FUNCTIONS --------------------------- */
    /* -------------------------------------------------------------------------- */

    /// @notice Return placeholder image for a Capsule
    /// @param capsuleId id of Capsule token
    function defaultImageOf(uint256 capsuleId)
        public
        view
        returns (string memory image)
    {
        bytes16[8] memory text;
        text[0] = bytes16("CAPSULE");
        text[1] = bytes16(
            abi.encodePacked("#", _bytes3ToHexChars(colorOf[capsuleId]))
        );

        image = imageFor(colorOf[capsuleId], text, fontWeightOf[capsuleId]);
    }

    /// @notice Return base64 encoded SVG for Capsule
    /// @param color color of Capsule token
    /// @param text text to render in image
    /// @param fontWeight fontWeight of Capsule text
    function imageFor(
        bytes3 color,
        bytes16[8] memory text,
        uint256 fontWeight
    ) public view returns (string memory image) {
        // Count the number of lines that are not empty. Only these lines will be rendered
        uint256 linesCount;
        {
            for (uint256 i = 8; i > 0; i--) {
                if (!_isEmptyLine(text[i - 1])) {
                    linesCount = i;
                    break;
                }
            }
        }

        bytes[8] memory safeText = _htmlSafeText(text);

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

        bytes memory hexColor = _bytes3ToHexChars(color);

        string memory _fontWeight = Strings.toString(fontWeight);

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
            Font memory font = Font({weight: fontWeight, style: "normal"});
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

    /// @notice Returns all Capsule data for capsuleId
    /// @param capsuleId ID of capsule
    function capsuleOf(uint256 capsuleId)
        external
        view
        returns (Capsule memory capsule)
    {
        capsule = Capsule({
            fontWeight: fontWeightOf[capsuleId],
            color: colorOf[capsuleId],
            text: textOf[capsuleId]
        });
    }

    /// @notice Return token URI for Capsule
    /// @param capsuleId id of Capsule token
    function tokenURI(uint256 capsuleId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(capsuleId), "ERC721A: URI query for nonexistent token");

        bytes16[8] memory text = textOf[capsuleId];

        string memory image;

        // If text contains invalid characters or is not set, use default image
        if (_isEmptyText(text) || !_isValidText(text)) {
            image = defaultImageOf(capsuleId);
        } else {
            image = imageFor(colorOf[capsuleId], text, fontWeightOf[capsuleId]);
        }

        bytes memory json = abi.encodePacked(
            '{"name": "Capsule ',
            Strings.toString(capsuleId),
            '", "description": "7,957 tokens with unique colors and editable text rendered on-chain. 7 pure colors are reserved for wallets that pay gas to store one of the 7 Capsules font weights in the CapsulesTypeface contract.", "image": "',
            image,
            '", "attributes": [{"trait_type": "Color", "value": "#',
            _bytes3ToHexChars(colorOf[capsuleId]),
            '"}, {"pure": "',
            _isReservedColor(colorOf[capsuleId]),
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

    /// @notice Mints Capsule to sender
    /// @dev Requires active sale, min value of `MINT_PRICE`, and unreserved color.
    /// @param color color of Capsule
    /// @param text text of Capsule
    /// @param fontWeight fontWeight of Capsule
    function mint(
        bytes3 color,
        bytes16[8] calldata text,
        uint256 fontWeight
    )
        external
        payable
        onlyUnreservedColor(color)
        whenNotPaused
        requireMintPrice
        nonReentrant
        returns (uint256 capsuleId)
    {
        capsuleId = _mintCapsule(msg.sender, color, text, fontWeight);
    }

    /// @notice Mints Capsule to sender
    /// @dev Requires active sale and reserved color.
    /// @param fontWeight fontWeight of Capsule
    /// @param text text of Capsule
    function mintReservedForFontWeight(
        address to,
        uint256 fontWeight,
        bytes16[8] calldata text
    )
        external
        onlyCapsulesTypeface
        whenNotPaused
        nonReentrant
        returns (uint256 capsuleId)
    {
        capsuleId = _mintCapsule(
            to,
            reservedColorForFontWeight(fontWeight),
            text,
            fontWeight
        );
    }

    /// @notice Allows address on claim list to mint Capsule
    /// @dev Requires active sale and for msg.sender to be on friends list.
    /// @param color color of Capsule
    /// @param text text of Capsule
    /// @param fontWeight fontWeight of Capsule
    function claim(
        bytes3 color,
        bytes16[8] calldata text,
        uint256 fontWeight
    )
        external
        onlyUnreservedColor(color)
        onlyClaimable
        whenNotPaused
        nonReentrant
        returns (uint256 capsuleId)
    {
        claimCount[msg.sender]--;

        capsuleId = _mintCapsule(msg.sender, color, text, fontWeight);

        emit ClaimCapsule(capsuleId, msg.sender, color, text, fontWeight);
    }

    /// @notice Withdraws up to 50% of revenue from primary mint to the fee receiver
    function withdraw() external nonReentrant {
        uint256 balance = address(this).balance;

        payable(creatorFeeReceiver).transfer(balance);

        emit Withdraw(creatorFeeReceiver, balance);
    }

    /* -------------------------------------------------------------------------- */
    /* ------------------------ CAPSULE OWNER FUNCTIONS ------------------------- */
    /* -------------------------------------------------------------------------- */

    /// @notice Allows owner of Capsule to update the Capsule text
    /// @dev Must send at least the value of `textEditFee`
    /// @param capsuleId id of Capsule token
    /// @param text new text for Capsule
    /// @param fontWeight new font weight for Capsule
    function editCapsule(
        uint256 capsuleId,
        bytes16[8] calldata text,
        uint256 fontWeight
    )
        public
        onlyCapsuleOwner(capsuleId)
        onlyValidText(text)
        onlyValidFontWeight(fontWeight)
        nonReentrant
    {
        textOf[capsuleId] = text;
        fontWeightOf[capsuleId] = fontWeight;

        emit EditCapsule(capsuleId, text, fontWeight);
    }

    /// @notice Burn a Capsule
    /// @param capsuleId id of Capsule token
    function burn(uint256 capsuleId)
        external
        onlyCapsuleOwner(capsuleId)
        nonReentrant
    {
        _burn(capsuleId);
    }

    /// @dev Allows contract to receive ETH
    receive() external payable {}

    /* -------------------------------------------------------------------------- */
    /* ---------------------------- OWNER FUNCTIONS ----------------------------- */
    /* -------------------------------------------------------------------------- */

    /// @notice Allows the owner to update creatorFeeReceiver
    /// @param _creatorFeeReceiver address of new creatorFeeReceiver
    function setCreatorFeeReceiver(address _creatorFeeReceiver)
        external
        onlyOwner
    {
        creatorFeeReceiver = _creatorFeeReceiver;

        emit SetCreatorFeeReceiver(_creatorFeeReceiver);
    }

    /// @notice Allows the owner to update friendsList
    /// @param recievers list of addresses that can claim
    /// @param number number of mints allowed for each receiver address
    function setClaimable(address[] calldata recievers, uint256 number)
        external
        onlyOwner
    {
        for (uint256 i; i < recievers.length; i++) {
            claimCount[recievers[i]] = number;
            emit SetClaimCount(recievers[i], number);
        }
    }

    /// @notice Allows the owner to update royalty amount
    /// @param _royalty new royalty amount
    function setRoyalty(uint256 _royalty) external onlyOwner {
        require(_royalty <= 1000);

        royalty = _royalty;

        emit SetRoyalty(_royalty);
    }

    /// @notice Returns the reserved color for a specific font weight
    /// @param fontWeight font weight
    function reservedColorForFontWeight(uint256 fontWeight)
        public
        view
        returns (bytes3)
    {
        // Map fontWeight to reserved color
        // 100 == reservedColors[0]
        // 200 == reservedColors[1]
        // 300 == reservedColors[2]
        // ...
        bytes3 color = reservedColors[(fontWeight / 100) - 1];

        assert(_isReservedColor(color));

        return color;
    }

    /// @notice Pause contract
    /// @dev Can only be called by the owner when the contract is unpaused.
    function pause() external override onlyOwner {
        _pause();
    }

    /// @notice Unpause contract
    /// @dev Can only be called by the owner when the contract is paused.
    function unpause() external override onlyOwner {
        _unpause();
    }

    /// @notice EIP2981 royalty standard
    function royaltyInfo(uint256, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        return (payable(this), (salePrice * royalty) / 1000);
    }

    /// @notice EIP2981 standard Interface return. Adds to ERC721A Interface returns.
    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, ERC721A)
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /* -------------------------------------------------------------------------- */
    /* --------------------------- INTERNAL FUNCTIONS --------------------------- */
    /* -------------------------------------------------------------------------- */

    /// @notice ERC721A override to start tokenId's at 1 instead of 0.
    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    /// @notice Mints Capsule
    /// @dev Stores `colorOf` and reverse mapping `tokenOfColor`
    /// @param color color of Capsule
    /// @param text text of Capsule
    /// @param fontWeight fontWeight of Capsule
    function _mintCapsule(
        address to,
        bytes3 color,
        bytes16[8] calldata text,
        uint256 fontWeight
    )
        internal
        onlyValidColor(color)
        onlyUnmintedColor(color)
        onlyValidFontWeight(fontWeight)
        returns (uint256 capsuleId)
    {
        _mint(to, 1, new bytes(0), false);

        capsuleId = _currentIndex - 1;

        colorOf[capsuleId] = color;
        tokenOfColor[color] = capsuleId;
        textOf[capsuleId] = text;
        fontWeightOf[capsuleId] = fontWeight;

        emit MintCapsule(capsuleId, to, color, text, fontWeight);
    }

    /// @notice Check if text is valid
    /// @dev Only allows bytes allowed by CapsulesTypeface, and 0x00. 0x00 characters are treated as spaces. A text that has not been set yet will contain only 0x00 bytes
    /// @param text text to check validity of
    function _isValidText(bytes16[8] memory text) internal view returns (bool) {
        for (uint256 i; i < 8; i++) {
            bytes16 line = text[i];

            for (uint256 j; j < line.length; j++) {
                bytes1 char = line[i];

                if (
                    !ITypeface(capsulesTypeface).isAllowedByte(char) &&
                    char != 0x00
                ) {
                    return false;
                }
            }
        }

        return true;
    }

    /// @notice Check if fontWeight is valid
    /// @param fontWeight font weight to check validity of
    function _isValidFontWeight(uint256 fontWeight)
        internal
        view
        returns (bool)
    {
        return
            ITypeface(capsulesTypeface)
                .fontSrc(Font({weight: fontWeight, style: "normal"}))
                .length > 0;
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

    /// @notice Check if color is valid for minting
    /// @dev Returns true if at least one byte == 0xFF (255), AND all byte values are evenly divisible by 5
    /// @param color color to check validity of
    function _isValidColor(bytes3 color) internal pure returns (bool) {
        // At least one byte must equal 0xff
        if (color[0] < 0xff && color[1] < 0xff && color[2] < 0xff) {
            return false;
        }

        // All bytes must be divisible by 5
        for (uint256 i; i < 3; i++) {
            if (uint8(color[i]) % 5 != 0) return false;
        }

        return true;
    }

    /// @notice Check if color is valid for minting
    /// @dev Returns true if at least one byte == 0xFF (255), AND all byte values are evenly divisible by 5
    /// @param color color to check validity of
    function _isReservedColor(bytes3 color) internal view returns (bool) {
        for (uint256 i; i < reservedColors.length; i++) {
            if (color == reservedColors[i]) return true;
        }

        return false;
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
