// SPDX-License-Identifier: GPL-3.0

/// @title Capsules Token
/// @author peri
/// @notice Each Capsule token has a unique color, custom text rendered as a SVG, and a single vote for a Delegate address. The text and Delegate vote for a Capsule can be updated at any time by its owner. The address with >50% of Delegate votes has permission to withdraw fees earned from the primary mint, change the fee for editing Capsule texts, and initiate and manage the auction of reserved Capsules.
/// @dev bytes3 type is used to store the 3 bytes of the rgb hex-encoded color that is unique to each capsule.

pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./Base64.sol";
import "./interfaces/ICapsulesAuctionHouse.sol";
import "./interfaces/ICapsulesToken.sol";
import "./interfaces/ITypeface.sol";

contract CapsulesToken is
    ICapsulesToken,
    ERC721Enumerable,
    ReentrancyGuard,
    Pausable,
    Ownable
{
    /*
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    MODIFIERS
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    */

    /// @notice Require that the value sent is at least MINT_PRICE
    modifier requireMintPrice() {
        require(
            msg.value >= MINT_PRICE,
            "Ether value sent is below the mint price"
        );
        _;
    }

    /// @notice Require that the value sent is at least textEditFee
    modifier requireSetTextPrice() {
        require(
            msg.value >= textEditFee,
            "Ether value sent is below cost to set text"
        );
        _;
    }

    /// @notice Require that the text is valid
    modifier onlyValidText(bytes16[8] calldata text) {
        require(_isValidText(text), "Invalid text");
        _;
    }

    /// @notice Require that the color is valid
    modifier onlyValidColor(bytes3 color) {
        require(_isValidColor(color), "Invalid color");
        _;
    }

    /// @notice Require that the color is not minted
    modifier onlyUnmintedColor(bytes3 color) {
        require(tokenOfColor[color] == 0, "Color already minted");
        _;
    }

    /// @notice Require that the color is not reserved for auction
    modifier onlyNotAuctionColor(bytes3 color) {
        for (uint256 i; i < auctionColors.length; i++) {
            if (auctionColors[i] == color) revert("Color reserved for auction");
        }
        _;
    }

    /// @notice Require that the sender is the Capsule owner
    modifier onlyCapsuleOwner(uint256 capsuleId) {
        require(ownerOf(capsuleId) == msg.sender, "Capsule not owned");
        _;
    }

    /// @notice Require that the sender is the minter
    modifier onlyAuctionHouse() {
        require(
            msg.sender == address(auctionHouse),
            "Sender is not the Auction House"
        );
        _;
    }

    /// @notice Require that the sender is the delegate
    modifier onlyDelegate() {
        require(isDelegate(msg.sender), "Sender is not the Delegate");
        _;
    }

    /*
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    CONSTRUCTOR
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    */

    constructor(
        uint256 _textEditFee,
        address _capsulesTypeface,
        address _auctionHouse,
        address _creatorFeeReceiver,
        bytes3[] memory _auctionColors
    ) ERC721("Capsules", "CAPS") {
        textEditFee = _textEditFee;
        capsulesTypeface = ITypeface(_capsulesTypeface);
        auctionHouse = ICapsulesAuctionHouse(_auctionHouse);
        creatorFeeReceiver = _creatorFeeReceiver;

        for (uint256 i; i < _auctionColors.length; i++) {
            require(_isValidColor(_auctionColors[i]), "Invalid auction color");
        }

        auctionColors = _auctionColors;

        _pause();
    }

    /*
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    VARIABLES
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    */

    /// The total number of valid colors
    uint256 public constant MAX_SUPPLY = 7957;

    /// Price to mint a Capsule
    uint256 public constant MINT_PRICE = 1e17; // 0.1 ETH

    /// Mapping of addresses to number of allowed mints
    mapping(address => uint256) public friendsList;

    /// Number of minted capsules
    uint256 public mintedCount;

    /// List of colors reserved for auction
    bytes3[] public auctionColors;

    /// Capsules typeface address
    ITypeface public immutable capsulesTypeface;

    /// Auction house address
    ICapsulesAuctionHouse public auctionHouse;

    /// Fee required to edit text for a Capsule token
    uint256 public textEditFee;

    /// Color for a token id
    mapping(uint256 => bytes3) public colorOf;

    /// Token id for a color
    mapping(bytes3 => uint256) public tokenOfColor;

    /// Text of a token id
    mapping(uint256 => bytes16[8]) public textOf;

    /// Delegate vote of a token id
    mapping(uint256 => address) public delegateVoteOf;

    /// Address to receive fees
    address public creatorFeeReceiver;

    /// Amount of fee withdrawn to `feeReceiver`
    uint256 public creatorFeeWithdrawn = 0;

    /*
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    EXTERNAL FUNCTIONS
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    */

    /// @notice Return placeholder image for a Capsule
    /// @param capsuleId id of Capsule token
    function defaultImageOf(uint256 capsuleId)
        public
        view
        returns (string memory image)
    {
        bytes16[8] memory text;
        text[0] = bytes16(
            abi.encodePacked("Capsule ", Strings.toString(capsuleId))
        );
        text[1] = bytes16(
            abi.encodePacked("Color  #", _bytes3ToHexColor(colorOf[capsuleId]))
        );

        image = imageOf(capsuleId, text);
    }

    /// @notice Return base64 encoded SVG for Capsule
    /// @param capsuleId id of Capsule token
    /// @param text text to render in image
    function imageOf(uint256 capsuleId, bytes16[8] memory text)
        public
        view
        returns (string memory image)
    {
        require(_exists(capsuleId), "Nonexistent token");

        bytes memory color = _bytes3ToHexColor(colorOf[capsuleId]);

        // Calculate number of lines of text that should be rendered
        uint256 linesCount;
        for (uint256 i = 8; i > 0; i--) {
            if (!_isEmptyLine(text[i - 1])) {
                linesCount = i;
                break;
            }
        }

        bytes[8] memory safeText = _htmlSafeText(text);

        uint256 longestLine;
        for (uint256 i; i < 8; i++) {
            if (safeText[i].length > longestLine) {
                longestLine = safeText[i].length;
            }
        }

        uint256 canvasWidthDots = longestLine * 5 + (longestLine - 1) + 6;
        uint256 canvasHeightDots = linesCount * 12 + 2;

        bytes memory rowId = abi.encodePacked(
            "row",
            Strings.toString(longestLine)
        );
        bytes memory textRowId = abi.encodePacked(
            "textRow",
            Strings.toString(longestLine)
        );

        // Reuse <g> elements instead of individual <circle> elements to minimize overall SVG size
        bytes
            memory dots1x12 = '<g id="dots1x12"><circle cx="2" cy="2" r="1.5"></circle><circle cx="2" cy="6" r="1.5"></circle><circle cx="2" cy="10" r="1.5"></circle><circle cx="2" cy="14" r="1.5"></circle><circle cx="2" cy="18" r="1.5"></circle><circle cx="2" cy="22" r="1.5"></circle><circle cx="2" cy="26" r="1.5"></circle><circle cx="2" cy="30" r="1.5"></circle><circle cx="2" cy="34" r="1.5"></circle><circle cx="2" cy="38" r="1.5"></circle><circle cx="2" cy="42" r="1.5"></circle><circle cx="2" cy="46" r="1.5"></circle></g>';

        bytes memory rowDots = abi.encodePacked('<g id="', rowId, '">');
        for (uint256 i; i < canvasWidthDots; i++) {
            rowDots = abi.encodePacked(
                rowDots,
                '<circle cx="',
                Strings.toString(4 * i + 2),
                '" cy="2" r="1.5"></circle>'
            );
        }
        rowDots = abi.encodePacked(rowDots, "</g>");

        bytes memory textRowDots = abi.encodePacked('<g id="', textRowId, '">');
        for (uint256 i; i < canvasWidthDots; i++) {
            textRowDots = abi.encodePacked(
                textRowDots,
                '<use href="#dots1x12" transform="translate(',
                Strings.toString(4 * i),
                ')"></use>'
            );
        }
        textRowDots = abi.encodePacked(textRowDots, "</g>");

        bytes memory dots = abi.encodePacked(
            '<g fill="#',
            color,
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

        bytes memory texts = abi.encodePacked(
            '<g fill="#',
            color,
            '" transform="translate(10 44)">'
        );
        for (uint256 i = 0; i < linesCount; i++) {
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

        bytes memory style = abi.encodePacked(
            '<style>text { font-family: Capsules; font-size: 40px; white-space: pre; } @font-face { font-family: "Capsules"; src: url(',
            capsulesTypeface.fontSrc(
                ITypeface.Font({weight: 400, style: "normal"})
            ),
            ")}</style>"
        );

        bytes memory svg = abi.encodePacked(
            '<svg viewBox="0 0 ',
            Strings.toString(canvasWidthDots * 4),
            " ",
            Strings.toString(canvasHeightDots * 4),
            '" preserveAspectRatio="xMidYMid meet" xmlns="http://www.w3.org/2000/svg"><defs>',
            dots1x12,
            rowDots,
            textRowDots,
            "</defs>",
            style,
            '<rect x="0" y="0" width="100%" height="100%" fill="#000"></rect>',
            dots,
            texts,
            "</svg>"
        );

        image = string(
            abi.encodePacked("data:image/svg+xml;base64,", Base64.encode(svg))
        );
    }

    /// @notice Return token URI for Capsule
    /// @param capsuleId id of Capsule token
    function tokenURI(uint256 capsuleId)
        public
        view
        override(ICapsulesToken, ERC721)
        returns (string memory)
    {
        require(
            _exists(capsuleId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        bytes16[8] memory text = textOf[capsuleId];

        string memory image;

        // If text contains invalid characters or is not set, use a default text instead
        if (_isEmptyText(text) || !_isValidText(text)) {
            image = defaultImageOf(capsuleId);
        } else {
            image = imageOf(capsuleId, text);
        }

        bytes memory json = abi.encodePacked(
            '{"name": "Capsule ',
            Strings.toString(capsuleId),
            '", "description": "Capsules are 10,000 editable text images rendered entirely on-chain.", "image": "',
            image,
            '", "attributes": [{"trait_type": "Color", "value": "#',
            _bytes3ToHexColor(colorOf[capsuleId]),
            '"}]}'
        );

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(json)
                )
            );
    }

    /// @notice Returns true if address has >50% of current delegate votes
    /// @dev Primary mint must complete before delegate is recognized
    /// @param _address address to check delegate status for
    function isDelegate(address _address) public view returns (bool) {
        // We use `mintedCount` instead of `totalSupply()` to allow for burning tokens, which reduce `totalSupply()`
        if (mintedCount < primarySupply()) return false;

        uint256 voteCount = 0;

        // Tally votes from all Capsules
        for (uint256 i; i < totalSupply(); i++) {
            if (delegateVoteOf[i] == _address) voteCount++;
            // `_address` has >50% of votes
            if (voteCount > (totalSupply() / 2)) return true;
        }

        return false;
    }

    /// @notice Get IDs for all Capsule tokens owned by wallet
    /// @param owner address to get token IDs for
    function tokensOfOwner(address owner)
        external
        view
        returns (uint256[] memory)
    {
        uint256 tokenCount = balanceOf(owner);
        if (tokenCount == 0) {
            // Return an empty array
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 index;
            for (index = 0; index < tokenCount; index++) {
                result[index] = tokenOfOwnerByIndex(owner, index);
            }
            return result;
        }
    }

    /// @notice Mints Capsule to sender
    /// @dev Requires active sale and min value of `MINT_PRICE`. Cannot be used to mint colors reserved for auction. If `setTextFee` is not greater than mint price, Minter can save on gas and avoid paying additional fee to set text by setting it here. To save gas regardless, function will only set text if not "empty"
    /// @param color color of Capsule
    /// @param text text of Capsule
    function mint(bytes3 color, bytes16[8] calldata text)
        external
        payable
        whenNotPaused
        onlyNotAuctionColor(color)
        requireMintPrice
        nonReentrant
        returns (uint256 capsuleId)
    {
        capsuleId = _mintCapsule(msg.sender, color);

        // Only setText if non-empty text is passed
        if (!_isEmptyText(text)) setText(capsuleId, text);
    }

    /// @notice Allows friend to claim Capsule
    /// @dev Requires active sale and for msg.sender to be on friends list. Cannot be used to mint colors reserved for auction.
    /// @param color color of Capsule
    function claim(bytes3 color)
        external
        whenNotPaused
        onlyNotAuctionColor(color)
        nonReentrant
        returns (uint256 capsuleId)
    {
        if (friendsList[msg.sender] < 1) revert("Not on Friends list");

        friendsList[msg.sender]--;

        capsuleId = _mintCapsule(msg.sender, color);

        emit CapsuleClaimed(
            msg.sender,
            capsuleId,
            string(_bytes3ToHexColor(color))
        );
    }

    /// @notice Mint Capsule for the next unminted auction color to the auction house
    function mintAuctionColor()
        public
        nonReentrant
        onlyAuctionHouse
        returns (uint256 capsuleId)
    {
        // Mint Capsule for first unminted color in `auctionColors`
        for (uint256 i; i < auctionColors.length; i++) {
            if (tokenOfColor[auctionColors[i]] == 0) {
                capsuleId = _mintCapsule(
                    address(auctionHouse),
                    auctionColors[i]
                );
            }
        }
    }

    /// @notice Withdraws up to 50% of revenue from primary mint to the fee receiver
    function withdrawCreatorFee() external nonReentrant {
        require(
            creatorFeeWithdrawn < maxCreatorFee(),
            "Cannot withdraw more than 50% of initial mint revenue for creator"
        );

        uint256 due = maxCreatorFee() - creatorFeeWithdrawn;
        uint256 amount;

        if (address(this).balance < due) amount = address(this).balance;
        else amount = due;

        creatorFeeWithdrawn += amount;
        payable(creatorFeeReceiver).transfer(amount);

        emit WithdrawCreatorFee(creatorFeeReceiver, amount);
    }

    /*
    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
                            CAPSULE OWNER FUNCTIONS
    ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    */

    /// @notice Allows owner of Capsule to update the Capsule text
    /// @dev Must send at least the value of `textEditFee`
    /// @param capsuleId id of Capsule token
    /// @param text new text for Capsule
    function setText(uint256 capsuleId, bytes16[8] calldata text)
        public
        payable
        onlyCapsuleOwner(capsuleId)
        onlyValidText(text)
        requireSetTextPrice
        nonReentrant
    {
        textOf[capsuleId] = text;

        emit SetText(capsuleId, text);
    }

    /// @notice Allows owner of Capsule to set Delegate vote of Capsule token
    /// @param capsuleId id of Capsule token
    /// @param delegate address of Delegate to vote for
    function setDelegateVote(uint256 capsuleId, address delegate)
        public
        onlyCapsuleOwner(capsuleId)
        nonReentrant
    {
        _setDelegateVote(capsuleId, delegate);
    }

    /// @notice Burn a Capsule
    /// @param capsuleId id of Capsule token
    function burn(uint256 capsuleId)
        public
        onlyCapsuleOwner(capsuleId)
        nonReentrant
    {
        _burn(capsuleId);
    }

    /// @dev Allows contract to receive ETH
    receive() external payable {}

    /*
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    DELEGATE FUNCTIONS
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    */

    /// @notice Allows Delegate to withdraw ETH
    /// @param amount amount of ETH to withdraw
    function withdraw(uint256 amount) external onlyDelegate nonReentrant {
        payable(msg.sender).transfer(amount);

        emit Withdraw(msg.sender, amount);
    }

    /// @notice Allows Delegate to update textEditFee
    /// @param _textEditFee new textEditFee
    function setTextEditFee(uint256 _textEditFee)
        external
        nonReentrant
        onlyDelegate
    {
        textEditFee = _textEditFee;

        emit SetTextEditFee(_textEditFee);
    }

    /*
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    OWNER FUNCTIONS
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    */

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
    /// @param friends list of friends' addresses
    /// @param number number of mints allowed for each address in friends
    function setFriendsList(address[] calldata friends, uint256 number)
        external
        onlyOwner
    {
        for (uint256 i; i < friends.length; i++) {
            friendsList[friends[i]] = number;
            emit SetFriend(friends[i], number);
        }
    }

    /// @notice Pause the Capsules auction house.
    /// @dev Can only be called by the owner when the contract is unpaused.
    function pause() external override onlyOwner {
        _pause();
    }

    /// @notice Unpause the Capsules auction house.
    /// @dev Can only be called by the owner when the contract is paused.
    function unpause() external override onlyOwner {
        _unpause();
    }

    /*
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    INTERNAL FUNCTIONS
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    */

    /// @notice Number of Capsules that can be minted outside of auction
    function primarySupply() internal view returns (uint256) {
        return MAX_SUPPLY - auctionColors.length;
    }

    /// @notice Max ETH fee that can be withdrawn to creator
    function maxCreatorFee() internal view returns (uint256) {
        return (primarySupply() * MINT_PRICE) / 2;
    }

    /// @notice Resets delegate vote of Capsule before token is transferred
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 capsuleId
    ) internal override(ERC721Enumerable) {
        _setDelegateVote(capsuleId, address(0));
        super._beforeTokenTransfer(from, to, capsuleId);
    }

    /// @notice Updates delegate vote for Capsule
    /// @param capsuleId id of Capsule token
    /// @param delegate address of Delegate to vote for
    function _setDelegateVote(uint256 capsuleId, address delegate) internal {
        delegateVoteOf[capsuleId] = delegate;

        emit SetDelegateVote(capsuleId, delegate);
    }

    /// @notice Mints Capsule
    /// @dev Sets token ID for new Capsule. Stores `colorOf` and reverse mapping `tokenOfColor`
    /// @param to address to receive Capsule
    /// @param color color of Capsule
    function _mintCapsule(address to, bytes3 color)
        internal
        onlyValidColor(color)
        onlyUnmintedColor(color)
        returns (uint256 capsuleId)
    {
        // Start ids at 1
        capsuleId = mintedCount + 1;
        mintedCount++;

        colorOf[capsuleId] = color;
        tokenOfColor[color] = capsuleId;

        _safeMint(to, capsuleId);

        emit CapsuleMinted(to, capsuleId, string(_bytes3ToHexColor(color)));
    }

    /// @notice Check if text is valid
    /// @dev Only allows bytes allowed by CapsulesTypeface, and 0x00. 0x00 characters are treated as spaces. A text that has not been set yet will contain only 0x00 bytes
    /// @param text text to check validity of
    function _isValidText(bytes16[8] memory text) internal view returns (bool) {
        for (uint256 i; i < 8; i++) {
            bytes16 line = text[i];

            for (uint256 j; j < line.length; j++) {
                bytes1 char = line[i];

                if (!capsulesTypeface.isAllowedByte(char) && char != 0x00) {
                    return false;
                }
            }
        }

        return true;
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
    /// @dev Returns true if at least one byte == 0xFF (255), AND all bytes are evely divisible by 0x05 (5)
    /// @param color color to check validity of
    function _isValidColor(bytes3 color) internal pure returns (bool) {
        if (color[0] < 0xff && color[1] < 0xff && color[2] < 0xff) {
            return false;
        }

        for (uint256 i; i < 3; i++) {
            if (uint8(color[i]) % 5 != 0) return false;
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

    /// @notice Format bytes3 type for use as hex color code in html
    function _bytes3ToHexColor(bytes3 b)
        internal
        pure
        returns (bytes memory o)
    {
        uint24 i = uint24(b);
        o = new bytes(6);
        uint24 mask = 0x00000f;
        o[5] = _uint8toHexChar(uint8(i & mask));
        i = i >> 4;
        o[4] = _uint8toHexChar(uint8(i & mask));
        i = i >> 4;
        o[3] = _uint8toHexChar(uint8(i & mask));
        i = i >> 4;
        o[2] = _uint8toHexChar(uint8(i & mask));
        i = i >> 4;
        o[1] = _uint8toHexChar(uint8(i & mask));
        i = i >> 4;
        o[0] = _uint8toHexChar(uint8(i & mask));
    }

    /// @notice Convert uint8 type to hex
    function _uint8toHexChar(uint8 i) internal pure returns (bytes1 b) {
        uint8 _i = (i > 9)
            ? (i + 87) // ascii a-f
            : (i + 48); // ascii 0-9

        b = bytes1(_i);
    }
}
