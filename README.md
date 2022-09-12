# Typeface Contract

The Typeface contract allows storing and retrieving font source data on-chain—base64 or otherwise encoded. 

## Storing font sources

Font source data can be large and cost large amounts of gas to store. To avoid surpassing gas limits in deploying a contract with included font source data, only a keccak256 hash of the data is stored when the contract is deployed. This allows font sources to be stored later in separate transactions, provided the hash of the data matches the hash previously stored for that font.

Fonts are identified by the Font struct, which specifies `style` and `weight` properties.

## Supported characters

Two functions allow specifying which characters are supported by the stored typeface. ASCII characters can be encoded in a single byte, so typefaces using only this charset can rely on the `isSupportedByte(bytes1)` function to specify if a character is supported. For charsets including more complex characters that require more than 1 byte to encode, `isSupportedBytes4(bytes4)` should be used.