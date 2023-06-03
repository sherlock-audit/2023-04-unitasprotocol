// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/ITokenPairs.sol";
import "./utils/Errors.sol";

/**
 * @title TokenPairs
 * @notice The abstract contract is used to manage pairs
 */
abstract contract TokenPairs is ITokenPairs {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /**
     * @notice Maps the token address to the set of addresses,
     *          where the key and each element in the set represents a pair of tokens.
     */
    mapping(address => EnumerableSet.AddressSet) internal _pairTokens;

    /**
     * @notice The set of pair hashes that is used to determine whether a pair exists in the pool
     */
    EnumerableSet.Bytes32Set internal _pairHashes;

    /**
     * @notice Emitted when the pair is added to the pool
     * @param pairHash The hash of the pair
     * @param tokenX The smaller token address
     * @param tokenY The larger token address
     */
    event PairAdded(bytes32 indexed pairHash, address indexed tokenX, address indexed tokenY);
    /**
     * @notice Emitted when the pair is removed from the pool
     * @param pairHash The hash of the pair
     * @param tokenX The smaller token address
     * @param tokenY The larger token address
     */
    event PairRemoved(bytes32 indexed pairHash, address indexed tokenX, address indexed tokenY);

    /**
     * @notice Gets an array of token addresses that are paired with the specified token, supporting pagination.
     *          Reverts if the index plus the count is out of bounds,
     *          or there is an overflow in the sum of index and count.
     * @param token The token address
     * @param index The offset of the list
     * @param count The number of tokens to retrieve
     * @return An array of token addresses that are paired with `token`
     */
    function listPairTokensByIndexAndCount(address token, uint256 index, uint256 count) external view virtual returns (address[] memory) {
        EnumerableSet.AddressSet storage tokenSet = _pairTokens[token];
        uint256 tokenCount = tokenSet.length();

        _require(
            (index == 0 || index < tokenCount) && index + count <= tokenCount,
            Errors.INPUT_OUT_OF_BOUNDS
        );

        address[] memory tokens = new address[](count);

        for (uint256 i; i < count; i++) {
            tokens[i] = tokenSet.at(index + i);
        }

        return tokens;
    }

    /**
     * @notice Sorts `tokenX` and `tokenY` and returns whether the pair is in the pool
     */
    function isPairInPool(address tokenX, address tokenY) public view virtual returns (bool) {
        return _pairHashes.contains(getPairHash(tokenX, tokenY));
    }

    /**
     * @notice Gets the total number of tokens that are paired with the specified token.
     * @param token The token address
     */
    function pairTokenLength(address token) public view virtual returns (uint256) {
        return _pairTokens[token].length();
    }

    /**
     * @notice Gets the paired token address by `token` and `index`
     */
    function pairTokenByIndex(address token, uint256 index) public view returns (address) {
        return _pairTokens[token].at(index);
    }

    /**
     * @notice Gets the total number of all pairs
     */
    function pairLength() public view virtual returns (uint256) {
        return _pairHashes.length();
    }

    /**
     * @notice Sorts `tokenX` and `tokenY` and gets the hash of the pair
     */
    function getPairHash(address tokenX, address tokenY) public pure virtual returns (bytes32) {
        (tokenX, tokenY) = _sortTokens(tokenX, tokenY);

        return _getPairHash(tokenX, tokenY);
    }

    /**
     * @notice Adds the pair to the pool, reverts if the pair does already exist.
     * @param tokenX The smaller token address
     * @param tokenY The larger token address
     */
    function _addPairByTokens(address tokenX, address tokenY) internal virtual returns (bytes32) {
        _require(tokenX < tokenY, Errors.TOKENS_NOT_SORTED);

        bytes32 pairHash = _getPairHash(tokenX, tokenY);

        _require(_pairHashes.add(pairHash), Errors.PAIR_ALREADY_EXISTS);
        _require(
            _pairTokens[tokenX].add(tokenY) && _pairTokens[tokenY].add(tokenX),
            Errors.PAIR_ALREADY_EXISTS
        );

        emit PairAdded(pairHash, tokenX, tokenY);

        return pairHash;
    }

    /**
     * @notice Removes the pair from the pool, reverts if the pair doesn't exist.
     * @param tokenX The smaller token address
     * @param tokenY The larger token address
     */
    function _removePairByTokens(address tokenX, address tokenY) internal virtual returns (bytes32) {
        bytes32 pairHash = _getPairHash(tokenX, tokenY);

        _require(_pairHashes.remove(pairHash), Errors.PAIR_NOT_EXISTS);
        _require(
            _pairTokens[tokenX].remove(tokenY) && _pairTokens[tokenY].remove(tokenX),
            Errors.PAIR_NOT_EXISTS
        );

        emit PairRemoved(pairHash, tokenX, tokenY);

        return pairHash;
    }

    /**
     * @notice Reverts if the pair does not exist
     * @param tokenX The smaller token address
     * @param tokenY The larger token address
     * @return The hash of the pair
     */
    function _checkPairExists(address tokenX, address tokenY) internal view virtual returns (bytes32) {
        bytes32 pairHash = _getPairHash(tokenX, tokenY);

        _require(_pairHashes.contains(pairHash), Errors.PAIR_NOT_EXISTS);

        return pairHash;
    }

    /**
     * @notice Encodes the hash by two token addresses in ascending order
     * @param tokenX The smaller token address
     * @param tokenY The larger token address
     * @return The pair of the hash
     */
    function _getPairHash(address tokenX, address tokenY) internal pure virtual returns (bytes32) {
        return keccak256(abi.encode(tokenX, tokenY));
    }

    /**
     * @notice Sorts the two token addresses in ascending order for encoding the hash
     * @return The smaller address and the larger address
     */
    function _sortTokens(address tokenX, address tokenY) internal pure virtual returns (address, address) {
        return tokenX < tokenY ? (tokenX, tokenY) : (tokenY, tokenX);
    }
}
