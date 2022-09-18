# Typeface Contract

The Typeface contract allows storing and retrieving font source data (base-64 or otherwise encoded) on-chain.

## Storing font sources

Font source data can be large and cost large amounts of gas to store. To avoid surpassing gas limits in deploying a contract with included font source data, only a keccak256 hash of the data is stored when the contract is deployed. This allows font sources to be stored later in separate transactions, provided the hash of the data matches the hash previously stored for that font.

Fonts are identified by the Font struct, which specifies `style` and `weight` properties.

## Supported characters

The function `supportsCodePoint(bytes3)` allows specifying which characters are supported by the stored typeface. All possible unicodes can be encoded using no more than 3 bytes.

## TypefaceExpandable

The TypefaceExpandable contract allows font hashes to be added or modified after deployment by an operator address. Hashes can only be modified until a source has been stored for that font.