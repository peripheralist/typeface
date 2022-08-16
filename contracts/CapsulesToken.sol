// SPDX-License-Identifier: GPL-3.0

/// @title Capsules Token

/// @author peri

/// @notice Each Capsule token has a unique color and a custom text rendered as a SVG. The text and fontWeight for a Capsule can be updated at any time by its owner.

/// @dev bytes3 type is used to store the rgb hex-encoded color that is unique to each capsule. bytes4[16][8] type is used to store text for Capsules: 8 lines of 16 characters, where each character is a bytes3. Using bytes3 for characters allows using more complex characters than ascii (bytes1).

pragma solidity 0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./ERC721A.sol";
import "./interfaces/ICapsulesMetadata.sol";
import "./interfaces/ICapsulesToken.sol";
import "./interfaces/ITypeface.sol";

error ValueBelowMintPrice();
error InvalidText();
error InvalidFontWeight();
error InvalidColor();
error PureColorNotAllowed();
error NotCapsulesTypeface();
error ColorAlreadyMinted(uint256 capsuleId);
error NotCapsuleOwner(address owner);
error CapsuleLocked();
error CapsuleMetadataLocked();

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
    /*       O   O   OOO   OOOO   OOOOO  OOOOO  OOOOO  OOOOO  OOOO    OOOO        */
    /*       OO OO  O   O  O   O    O    O        O    O      O   O  O            */
    /*       O O O  O   O  O   O    O    OOOOO    O    OOOOO  OOOO    OOO         */
    /*       O   O  O   O  O   O    O    O        O    O      O O        O        */
    /*       O   O   OOO   OOOO   OOOOO  O      OOOOO  OOOOO  O  O   OOOO         */

    /// @notice Require that the value sent is at least MINT_PRICE
    modifier requireMintPrice() {
        if (msg.value < MINT_PRICE) revert ValueBelowMintPrice();
        _;
    }

    /// @notice Require that the text is valid
    modifier onlyValidText(bytes4[16][8] calldata text) {
        if (!_isValidText(text)) revert InvalidText();
        _;
    }

    /// @notice Require that the text is valid
    modifier onlyValidFontWeight(uint256 fontWeight) {
        if (!_isValidFontWeight(fontWeight)) revert InvalidFontWeight();
        _;
    }

    /// @notice Require that the color is valid
    modifier onlyValidColor(bytes3 color) {
        if (!_isValidColor(color)) revert InvalidColor();
        _;
    }

    /// @notice Require that the color is not pure
    modifier onlyImpureColor(bytes3 color) {
        if (isPureColor(color)) revert PureColorNotAllowed();
        _;
    }

    /// @notice Require that the sender is the Capsules Typeface contract
    modifier onlyCapsulesTypeface() {
        if (msg.sender != capsulesTypeface) revert NotCapsulesTypeface();
        _;
    }

    /// @notice Require that the capsule is unlocked
    modifier onlyUnlockedCapsule(uint256 capsuleId) {
        if (isLocked(capsuleId)) revert CapsuleLocked();
        _;
    }

    /// @notice Require that the color is not minted
    modifier onlyUnmintedColor(bytes3 color) {
        uint256 capsuleId = tokenIdOfColor[color];
        if (_exists(capsuleId)) revert ColorAlreadyMinted(capsuleId);
        _;
    }

    /// @notice Require that the sender is the Capsule owner
    modifier onlyCapsuleOwner(uint256 capsuleId) {
        address owner = ownerOf(capsuleId);
        if (owner != msg.sender) revert NotCapsuleOwner(owner);
        _;
    }

    /// @notice Require that metadata has not been locked
    modifier onlyIfMetadataUnlocked() {
        if (metadataLocked) revert CapsuleMetadataLocked();
        _;
    }

    /* -------------------------------------------------------------------------- */
    /* ------------------------------- CONSTRUCTOR ------------------------------ */
    /* -------------------------------------------------------------------------- */

    constructor(
        address _capsulesTypeface,
        address _capsulesMetadata,
        address _creatorFeeReceiver,
        bytes3[] memory _pureColors,
        uint256 _royalty
    ) ERC721A("Capsules", "CAPS") {
        capsulesTypeface = _capsulesTypeface;
        capsulesMetadata = _capsulesMetadata;
        creatorFeeReceiver = _creatorFeeReceiver;
        pureColors = _pureColors;
        emit SetPureColors(_pureColors);
        royalty = _royalty;

        _pause();
    }

    /* -------------------------------------------------------------------------- */
    /* -------------------------------- VARIABLES ------------------------------- */
    /* -------------------------------------------------------------------------- */

    /// Price to mint a Capsule
    uint256 public constant MINT_PRICE = 1e16; // 0.01 ETH

    /// Capsules typeface address
    address public immutable capsulesTypeface;

    /// CapsulesMetadata address
    address public capsulesMetadata;

    /// Mapping of minted color to Capsule ID
    mapping(bytes3 => uint256) public tokenIdOfColor;

    /// Array of pure colors
    bytes3[] public pureColors;

    /// Address to receive fees
    address public creatorFeeReceiver;

    /// Royalty amount out of 1000
    uint256 public royalty;

    /// CapsulesMetadata contract address cannot be updated if locked
    bool public metadataLocked;

    // /// Mapping of Capsule ID to Capsule data
    // mapping(uint256 => Capsule) internal _capsuleOf;

    /// Mapping of Capsule ID to text
    mapping(uint256 => bytes4[16][8]) internal _textOf;

    /// Mapping of Capsule ID to color
    mapping(uint256 => bytes3) internal _colorOf;

    /// Mapping of Capsule ID to font weight
    mapping(uint256 => uint256) internal _fontWeightOf;

    /// Mapping of Capsule ID to locked state
    mapping(uint256 => bool) internal _locked;

    /* -------------------------------------------------------------------------- */
    /* --------------------------- EXTERNAL FUNCTIONS --------------------------- */
    /* -------------------------------------------------------------------------- */

    /// @notice Return token URI for Capsule.
    /// @param capsuleId ID of Capsule token.
    /// @return metadata Metadata for Capsule encoded via capsulesMetadata contract.
    function tokenURI(uint256 capsuleId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(capsuleId), "ERC721A: URI query for nonexistent token");

        return
            ICapsulesMetadata(capsulesMetadata).tokenUri(capsuleOf(capsuleId));
    }

    /// @notice Return SVG image of Capsule.
    /// @param capsuleId ID of Capsule token.
    /// @param square Format the Capsule image inside a square viewbox.
    /// @return svg SVG image of Capsule.
    function svgOf(uint256 capsuleId, bool square)
        public
        view
        returns (string memory)
    {
        return
            ICapsulesMetadata(capsulesMetadata).svgOf(
                capsuleOf(capsuleId),
                square
            );
    }

    /// @notice Returns data for Capsule with ID.
    /// @param capsuleId ID of Capsule.
    /// @return capsule Data for Capsule with ID.
    function capsuleOf(uint256 capsuleId)
        public
        view
        returns (Capsule memory capsule)
    {
        bytes3 color = _colorOf[capsuleId];

        capsule = Capsule({
            id: capsuleId,
            fontWeight: _fontWeightOf[capsuleId],
            text: _textOf[capsuleId],
            color: color,
            isPure: isPureColor(color),
            isLocked: _locked[capsuleId]
        });
    }

    /// @notice Check if color is valid for minting.
    /// @param color Color to check validity of.
    /// @return true True if color is pure.
    function isPureColor(bytes3 color) public view returns (bool) {
        for (uint256 i; i < pureColors.length; i++) {
            if (color == pureColors[i]) return true;
        }

        return false;
    }

    /// @notice Check if Capsule is locked.
    /// @param capsuleId ID of Capsule
    /// @return true True if Capsule is locked.
    function isLocked(uint256 capsuleId) public view returns (bool) {
        return _locked[capsuleId];
    }

    /// @notice Mints a Capsule to sender.
    /// @dev Requires active sale, min value of `MINT_PRICE`, and impure color.
    /// @param color Color for Capsule.
    /// @param text Text for Capsule. 8 lines of 16 bytes3 characters in 2d array.
    /// @param fontWeight FontWeight of Capsule.
    /// @param lock Permanently prevent Capsule from being edited.
    /// @return capsuleId ID of minted Capsule.
    function mint(
        bytes3 color,
        bytes4[16][8] calldata text,
        uint256 fontWeight,
        bool lock
    )
        external
        payable
        onlyImpureColor(color)
        whenNotPaused
        requireMintPrice
        nonReentrant
        returns (uint256 capsuleId)
    {
        capsuleId = _mintCapsule(msg.sender, color, text, fontWeight, lock);
    }

    /// @notice Mints Capsule to sender.
    /// @dev Requires active sale and pure color. No option to lock Capsule.
    /// @param fontWeight fontWeight of Capsule.
    /// @param text Text for Capsule. 8 lines of 16 bytes3 characters in 2d array.
    /// @return capsuleId ID of minted Capsule.
    function mintPureColorForFontWeight(
        address to,
        uint256 fontWeight,
        bytes4[16][8] calldata text
    )
        external
        onlyCapsulesTypeface
        whenNotPaused
        nonReentrant
        returns (uint256 capsuleId)
    {
        capsuleId = _mintCapsule(
            to,
            pureColorForFontWeight(fontWeight),
            text,
            fontWeight,
            false
        );
    }

    /// @notice Allows Capsule owner to permanently lock the Capsule, preventing it from being edited.
    /// @param capsuleId ID of Capsule to lock.
    function lockCapsule(uint256 capsuleId)
        external
        onlyCapsuleOwner(capsuleId)
        nonReentrant
    {
        _lockCapsule(capsuleId);
    }

    /// @notice Withdraws balance of this contract to the creatorFeeReceiver address.
    function withdraw() external nonReentrant {
        uint256 balance = address(this).balance;

        payable(creatorFeeReceiver).transfer(balance);

        emit Withdraw(creatorFeeReceiver, balance);
    }

    /// @notice Returns the pure color matching a specific font weight.
    /// @param fontWeight Font weight to return pure color for.
    /// @return color Color for font weight.
    function pureColorForFontWeight(uint256 fontWeight)
        public
        view
        returns (bytes3 color)
    {
        // Map fontWeight to pure color
        // 100 == pureColors[0]
        // 200 == pureColors[1]
        // 300 == pureColors[2]
        // ...
        color = pureColors[(fontWeight / 100) - 1];
    }

    /// @notice EIP2981 royalty standard
    function royaltyInfo(uint256, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        // TODO verify correct
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
        // TODO verify correct
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @dev Allows contract to receive ETH
    receive() external payable {}

    /* -------------------------------------------------------------------------- */
    /* ------------------------ CAPSULE OWNER FUNCTIONS ------------------------- */
    /* -------------------------------------------------------------------------- */

    /// @notice Allows the owner of the Capsule to update the Capsule text, fontWeight, and locked state.
    /// @param capsuleId ID of Capsule.
    /// @param text New text for Capsule. 8 lines of 16 bytes3 characters in 2d array.
    /// @param fontWeight New font weight for Capsule.
    function editCapsule(
        uint256 capsuleId,
        bytes4[16][8] calldata text,
        uint256 fontWeight,
        bool lock
    )
        public
        onlyCapsuleOwner(capsuleId)
        onlyUnlockedCapsule(capsuleId)
        onlyValidText(text)
        onlyValidFontWeight(fontWeight)
        nonReentrant
    {
        _textOf[capsuleId] = text;
        _fontWeightOf[capsuleId] = fontWeight;

        emit EditCapsule(capsuleId, text, fontWeight);

        if (lock) _lockCapsule(capsuleId);
    }

    /// @notice Burns a Capsule token.
    /// @param capsuleId ID of Capsule token to burn.
    function burn(uint256 capsuleId)
        external
        onlyCapsuleOwner(capsuleId)
        nonReentrant
    {
        _burn(capsuleId);
    }

    /* -------------------------------------------------------------------------- */
    /* ---------------------------- ADMIN FUNCTIONS ----------------------------- */
    /* -------------------------------------------------------------------------- */

    /// @notice Allows the contract owner to update the capsulesMetadata contract.
    /// @param _capsulesMetadata Address of new CapsulesMetadata contract.
    function setCapsulesMetadata(address _capsulesMetadata)
        external
        onlyOwner
        onlyIfMetadataUnlocked
    {
        // TODO IERC165 check interface
        capsulesMetadata = _capsulesMetadata;

        emit SetCapsulesMetadata(_capsulesMetadata);
    }

    /// @notice Allows the contract owner to permanently prevent the capsulesMetadata contract from being updated.
    function lockMetadata() external onlyOwner onlyIfMetadataUnlocked {
        metadataLocked = true;

        emit LockMetadata();
    }

    /// @notice Allows the owner to update creatorFeeReceiver.
    /// @param _creatorFeeReceiver Address of new creatorFeeReceiver.
    function setCreatorFeeReceiver(address _creatorFeeReceiver)
        external
        onlyOwner
    {
        creatorFeeReceiver = _creatorFeeReceiver;

        emit SetCreatorFeeReceiver(_creatorFeeReceiver);
    }

    /// @notice Allows the owner to update the royalty amount.
    /// @param _royalty New royalty amount.
    function setRoyalty(uint256 _royalty) external onlyOwner {
        require(_royalty <= 1000, "Amount too high");

        royalty = _royalty;

        emit SetRoyalty(_royalty);
    }

    /// @notice Allows the contract owner to pause the contract.
    /// @dev Can only be called by the owner when the contract is unpaused.
    function pause() external override onlyOwner {
        _pause();
    }

    /// @notice Allows the contract owner to unpause the contract.
    /// @dev Can only be called by the owner when the contract is paused.
    function unpause() external override onlyOwner {
        _unpause();
    }

    /* -------------------------------------------------------------------------- */
    /* --------------------------- INTERNAL FUNCTIONS --------------------------- */
    /* -------------------------------------------------------------------------- */

    /// @notice ERC721A override to start tokenId's at 1 instead of 0.
    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    /// @notice Mints a Capsule to sender.
    /// @dev Stores Capsule data in `_capsuleOf`, and mapping `tokenIdOfColor`.
    /// @param color Color of Capsule.
    /// @param text Text for Capsule. 8 lines of 16 bytes3 characters in 2d array.
    /// @param fontWeight FontWeight of Capsule.
    /// @param lock Permanently prevent Capsule from being edited.
    /// @return capsuleId ID of minted Capsule.
    function _mintCapsule(
        address to,
        bytes3 color,
        bytes4[16][8] calldata text,
        uint256 fontWeight,
        bool lock
    )
        internal
        onlyValidColor(color)
        onlyUnmintedColor(color)
        onlyValidFontWeight(fontWeight)
        returns (uint256 capsuleId)
    {
        _mint(to, 1, new bytes(0), false);

        capsuleId = _currentIndex - 1;

        tokenIdOfColor[color] = capsuleId;
        _colorOf[capsuleId] = color;
        _textOf[capsuleId] = text;
        _fontWeightOf[capsuleId] = fontWeight;

        emit MintCapsule(capsuleId, to, color, text, fontWeight);

        if (lock) _lockCapsule(capsuleId);
    }

    function _lockCapsule(uint256 capsuleId)
        internal
        onlyUnlockedCapsule(capsuleId)
    {
        _locked[capsuleId] = true;
        emit LockCapsule(capsuleId);
    }

    /// @notice Check if text is valid.
    /// @dev Only allows bytes allowed by CapsulesTypeface, and 0x00. Non-trailing 0x00 bytes are treated as spaces, trailing 0x00 bytes are ignored.
    /// @param text Text to check validity of. 8 lines of 16 bytes3 characters in 2d array.
    /// @return true True if text is valid.
    function _isValidText(bytes4[16][8] memory text)
        internal
        view
        returns (bool)
    {
        for (uint256 i; i < 8; i++) {
            bytes4[16] memory line = text[i];

            for (uint256 j; j < 16; j++) {
                bytes4 char = line[j];

                if (
                    !ITypeface(capsulesTypeface).isAllowedChar(char) &&
                    char != bytes4(0)
                ) {
                    return false;
                }
            }
        }

        return true;
    }

    /// @notice Check if font weight is valid.
    /// @dev A fontWeight is valid if its source has been set in the CapsulesTypeface contract.
    /// @param fontWeight Font weight to check validity of.
    /// @return true True if font weight is valid.
    function _isValidFontWeight(uint256 fontWeight)
        internal
        view
        returns (bool)
    {
        return
            ITypeface(capsulesTypeface)
                .sourceOf(Font({weight: fontWeight, style: "normal"}))
                .length > 0;
    }

    /// @notice Check if color is valid.
    /// @dev A bytes3 color is valid if at least one byte == 0xFF (255), AND all byte values are evenly divisible by 5.
    /// @param color Folor to check validity of.
    /// @return true True if color is valid.
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
}
