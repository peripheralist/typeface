// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./typeface/ITypeface.sol";

pragma solidity 0.8.12;

contract Capsules is ERC721Enumerable, Ownable {
    modifier onlyCapsuleOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, "Capsule not owned");
        _;
    }

    event Mint(address to, uint256 id, bytes15[7] note);
    event SetNote(uint256 id, bytes15[7] note);
    event SetRecipientVote(uint256 id, address recipient);
    event WithdrawToRecipient(address recipient, uint256 amount);

    ITypeface public immutable absoluteType;

    bool public saleIsActive = false;
    uint256 public withdrawnToOwner = 0;

    mapping(uint256 => bytes15[7]) public noteOf;
    mapping(uint256 => address) public recipientVoteOf;

    uint256 public immutable MAX_SUPPLY;
    uint256 public constant MINT_PRICE = 1e17; // 0.1 ETH
    uint256 public constant SET_NOTE_PRICE = 1e16; // 0.01 ETH

    constructor(
        address owner,
        uint256 maxSupply,
        ITypeface _absoluteType
    ) ERC721("Capsules", "CAPS") {
        transferOwnership(owner);
        MAX_SUPPLY = maxSupply;
        absoluteType = _absoluteType;
    }

    function imageOf(uint256 tokenId) public view returns (string memory) {
        bytes15[7] memory note = noteOf[tokenId];

        // Note may be invalid if it has not been set, or if it contains invalid characters
        // In either condition, we use a default note instead
        if (!_isValidNote(note)) {
            note[0] = bytes15(
                abi.encodePacked("Capsule ", Strings.toString(tokenId))
            );
            note[1] = bytes15(0);
            note[2] = bytes15(0);
            note[3] = bytes15(0);
            note[4] = bytes15(0);
            note[5] = bytes15(0);
            note[6] = bytes15(0);
        }

        // Reuse <g> elements of dots instead of individual <circle> elements to minimize overall SVG size

        string
            memory dots10x1 = '<g id="dots10x1"><circle cx="2" cy="2" r="1.5"></circle><circle cx="6" cy="2" r="1.5"></circle><circle cx="10" cy="2" r="1.5"></circle><circle cx="14" cy="2" r="1.5"></circle><circle cx="18" cy="2" r="1.5"></circle><circle cx="22" cy="2" r="1.5"></circle><circle cx="26" cy="2" r="1.5"></circle><circle cx="30" cy="2" r="1.5"></circle><circle cx="34" cy="2" r="1.5"></circle><circle cx="38" cy="2" r="1.5"></circle></g>';

        string
            memory dots100x1 = '<g id="dots100x1"><use href="#dots10x1" transform="translate(0 0)"></use><use href="#dots10x1" transform="translate(40 0)"></use><use href="#dots10x1" transform="translate(80 0)"></use><use href="#dots10x1" transform="translate(120 0)"></use><use href="#dots10x1" transform="translate(160 0)"></use><use href="#dots10x1" transform="translate(200 0)"></use><use href="#dots10x1" transform="translate(240 0)"></use><use href="#dots10x1" transform="translate(280 0)"></use><use href="#dots10x1" transform="translate(320 0)"></use><use href="#dots10x1" transform="translate(360 0)"></use></g>';

        string
            memory dots100x10 = '<g id="dots100x10"><use href="#dots100x1" transform="translate(0 0)"></use><use href="#dots100x1" transform="translate(0 4)"></use><use href="#dots100x1" transform="translate(0 8)"></use><use href="#dots100x1" transform="translate(0 12)"></use><use href="#dots100x1" transform="translate(0 16)"></use><use href="#dots100x1" transform="translate(0 20)"></use><use href="#dots100x1" transform="translate(0 24)"></use><use href="#dots100x1" transform="translate(0 28)"></use><use href="#dots100x1" transform="translate(0 32)"></use><use href="#dots100x1" transform="translate(0 36)"></use></g>';

        bytes4 color = _colorFor(tokenId);

        bytes memory dots = abi.encodePacked(
            '<g fill="',
            color,
            '" opacity="0.3"><use href="#dots100x10" transform="translate(0 0)"/><use href="#dots100x10" transform="translate(0 40)"/><use href="#dots100x10" transform="translate(0 80)"/><use href="#dots100x10" transform="translate(0 120)"/><use href="#dots100x10" transform="translate(0 160)"/><use href="#dots100x10" transform="translate(0 200)"/><use href="#dots100x10" transform="translate(0 240)"/><use href="#dots100x10" transform="translate(0 280)"/><use href="#dots100x10" transform="translate(0 320)"/><use href="#dots100x10" transform="translate(0 360)"/></g>'
        );

        bytes[7] memory safeNote = _htmlSafeNote(note);

        // Split up this encoding to avoid stack too deep
        bytes memory texts = abi.encodePacked(
            '<g fill="',
            color,
            '" transform="translate(18 0)"><text y="52" class="capsule">',
            safeNote[0],
            '</text><text y="104" class="capsule">',
            safeNote[1],
            '</text><text y="156" class="capsule">',
            safeNote[2],
            '</text><text y="208" class="capsule">'
        );
        texts = abi.encodePacked(
            texts,
            safeNote[3],
            '</text><text y="260" class="capsule">',
            safeNote[4],
            '</text><text y="312" class="capsule">',
            safeNote[5],
            '</text><text y="364" class="capsule">',
            safeNote[6],
            "</text></g>"
        );

        bytes memory style = abi.encodePacked(
            '<style>.capsule { font-family: Capsule; font-size: 40px; white-space: pre; } @font-face { font-family: "Capsule"; src: url(',
            absoluteType.fontSrc(
                Font({weight: 400, style: bytes32("regular")})
            ),
            ")}</style>"
        );

        bytes memory svg = abi.encodePacked(
            '<svg viewBox="0 0 400 400" preserveAspectRatio="xMidYMid meet" xmlns="http://www.w3.org/2000/svg">',
            "<defs>",
            dots10x1,
            dots100x1,
            dots100x10,
            "</defs>",
            style,
            '<rect x="0" y="0" width="100%" height="100%" fill="#000"></rect>',
            dots,
            texts,
            "</svg>"
        );

        return
            string(
                abi.encodePacked(
                    "data:image/svg+xml;base64,",
                    Base64.encode(svg)
                )
            );
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        bytes memory json = abi.encodePacked(
            '{"name": "Capsule ',
            Strings.toString(tokenId),
            '", "description": "Capsules are 10,000 owner-editable notes with text and image data stored on-chain.", "image": "',
            imageOf(tokenId),
            '", "attributes": [{"trait_type": "Color", "value": "',
            _colorNameFor(tokenId),
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

    // Get IDs for all tokens owned by `_owner`
    function tokensOfOwner(address _owner)
        external
        view
        returns (uint256[] memory)
    {
        uint256 tokenCount = balanceOf(_owner);
        if (tokenCount == 0) {
            // Return an empty array
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 index;
            for (index = 0; index < tokenCount; index++) {
                result[index] = tokenOfOwnerByIndex(_owner, index);
            }
            return result;
        }
    }

    function setNote(uint256 tokenId, bytes15[7] calldata note)
        public
        payable
        onlyCapsuleOwner(tokenId)
    {
        require(_isValidNote(note), "Note is invalid");
        require(
            msg.value >= SET_NOTE_PRICE,
            "Ether value sent is below cost to set note"
        );

        noteOf[tokenId] = note;

        emit SetNote(tokenId, note);
    }

    function setRecipientVote(uint256 tokenId, address recipient)
        public
        onlyCapsuleOwner(tokenId)
    {
        recipientVoteOf[tokenId] = recipient;

        emit SetRecipientVote(tokenId, recipient);
    }

    function mint(bytes15[7] calldata note) external payable returns (uint256) {
        require(saleIsActive, "Sale is inactive");
        require(totalSupply() < MAX_SUPPLY, "All Capsules have been minted");
        require(
            msg.value >= MINT_PRICE,
            "Ether value sent is below the mint price"
        );

        // Start IDs at 1
        uint256 tokenId = totalSupply() + 1;

        _safeMint(msg.sender, tokenId);

        emit Mint(msg.sender, tokenId, note);

        // Don't use gas to call setNote if empty note is passed
        if (_isValidNote(note)) setNote(tokenId, note);

        return tokenId;
    }

    function withdrawToRecipient(address recipient, uint256 amount) external {
        require(recipient != address(0), "Cannot withdraw to zero address");

        uint256 votes = 0;

        // Tally votes from all Capsules
        for (uint256 i; i < totalSupply(); i++) {
            if (recipientVoteOf[i] == recipient) votes++;
        }

        require(votes > (totalSupply() / 2), "Recipient is not majority");

        payable(recipient).transfer(amount);

        emit WithdrawToRecipient(recipient, amount);
    }

    function withdrawToOwner(uint256 amount) external {
        require(
            (withdrawnToOwner + amount) <= ((MAX_SUPPLY * MINT_PRICE) / 2),
            "Owner cannot withdraw more than 50% of initial mint revenue"
        );

        withdrawnToOwner += amount;

        payable(owner()).transfer(amount);
    }

    function setSaleIsActive(bool isActive) external onlyOwner {
        require(saleIsActive != isActive, "Cannot set to current state");
        saleIsActive = isActive;
    }

    function _isValidNote(bytes15[7] memory note) internal view returns (bool) {
        for (uint256 i; i < 7; i++) {
            bytes15 line = note[i];

            for (uint256 j; j < line.length; j++) {
                bytes1 char = line[i];

                if (!(absoluteType.isAllowedByte(char) && char != 0x00)) {
                    return false;
                }
            }
        }

        return true;
    }

    function _htmlSafeNote(bytes15[7] memory note)
        internal
        pure
        returns (bytes[7] memory safeNote)
    {
        // If we are using a stored note value, replace special characters that may cause trouble rendering with html-friendly codes
        for (uint16 i; i < 7; i++) {
            for (uint16 j; j < 15; j++) {
                if (note[i][j] == 0x3c) {
                    // Replace `<`
                    safeNote[i] = abi.encodePacked(safeNote[i], "&lt;");
                } else if (note[i][j] == 0x3E) {
                    // Replace `>`
                    safeNote[i] = abi.encodePacked(safeNote[i], "&gt;");
                } else if (note[i][j] == 0x26) {
                    // Replace `&`
                    safeNote[i] = abi.encodePacked(safeNote[i], "&amp;");
                } else if (note[i][j] == 0x00) {
                    // Replace invalid character with space
                    safeNote[i] = abi.encodePacked(safeNote[i], bytes1(0x20));
                } else {
                    safeNote[i] = abi.encodePacked(safeNote[i], note[i][j]);
                }
            }
        }
    }

    function _schemeFor(uint256 tokenId) internal pure returns (uint256) {
        // 0 = cyan
        // 1 = pink
        // 2 = yellow
        // 3 = white
        return tokenId % 4;
    }

    function _colorFor(uint256 tokenId) internal pure returns (bytes4 color) {
        // Define color scheme
        uint256 scheme = _schemeFor(tokenId);
        if (scheme == 0) color = "#0ff";
        if (scheme == 1) color = "#f0f";
        if (scheme == 2) color = "#ff0";
        if (scheme == 3) color = "#fff";
    }

    function _colorNameFor(uint256 tokenId)
        internal
        pure
        returns (string memory colorName)
    {
        if (_schemeFor(tokenId) == 0) colorName = "white";
        if (_schemeFor(tokenId) == 1) colorName = "red";
        if (_schemeFor(tokenId) == 2) colorName = "blue";
        if (_schemeFor(tokenId) == 3) colorName = "yellow";
        if (_schemeFor(tokenId) == 4) colorName = "pink";
    }
}

/// [MIT License]
/// @title Base64
/// @notice Provides a function for encoding some bytes in base64
/// @author Brecht Devos <brecht@loopring.org>
library Base64 {
    bytes internal constant TABLE =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /// @notice Encodes some bytes to the base64 representation
    function encode(bytes memory data) internal pure returns (string memory) {
        uint256 len = data.length;
        if (len == 0) return "";

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((len + 2) / 3);

        // Add some extra buffer at the end
        bytes memory result = new bytes(encodedLen + 32);

        bytes memory table = TABLE;

        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)

            for {
                let i := 0
            } lt(i, len) {

            } {
                i := add(i, 3)
                let input := and(mload(add(data, i)), 0xffffff)

                let out := mload(add(tablePtr, and(shr(18, input), 0x3F)))
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF)
                )
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF)
                )
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(input, 0x3F))), 0xFF)
                )
                out := shl(224, out)

                mstore(resultPtr, out)

                resultPtr := add(resultPtr, 4)
            }

            switch mod(len, 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }

            mstore(result, encodedLen)
        }

        return string(result);
    }
}
