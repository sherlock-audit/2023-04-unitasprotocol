// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/ITypeTokens.sol";
import "./utils/AddressUtils.sol";
import "./utils/Errors.sol";

/**
 * @title TypeTokens
 * @notice The abstract contract is used to manage pool tokens and classify them by type.
 * @dev Token types are stored using uint8.
 *       By default, a valid token type must be greater than zero to determine whether a token is in the pool.
 *       Child contracts can define their own enum for token types.
 */
abstract contract TypeTokens is ITypeTokens {
    using EnumerableSet for EnumerableSet.AddressSet;

    /**
     * @notice Maps the token address to the token type
     */
    mapping(address => uint8) internal _tokenType;
    /**
     * @notice Maps the token type to the address set of tokens
     */
    mapping(uint8 => EnumerableSet.AddressSet) internal _typeTokens;

    /**
     * @notice Emitted when `token` is added to the pool
     */
    event TokenAdded(address indexed token, uint8 tokenType);
    /**
     * @notice Emitted when `token` is removed from the pool
     */
    event TokenRemoved(address indexed token, uint8 tokenType);

    // ============================== MODIFIERS ==============================

    error TokenNotInPool(address token);
    error TokenAlreadyInPool(address token);

    /**
     * @notice Reverts if `token` is not in the pool
     */
    modifier tokenInPool(address token) {
        if (!isTokenInPool(token))
            revert TokenNotInPool(token);
        _;
    }

    /**
     * @notice Reverts if `token` is in the pool
     */
    modifier tokenNotInPool(address token) {
        if (isTokenInPool(token))
            revert TokenAlreadyInPool(token);
        _;
    }

    // ============================== EXTERNAL FUNCTIONS ===========================

    /**
     * @notice Gets an array of token addresses with the specified token type, supporting pagination.
     *          Reverts if the index plus the count is out of bounds,
     *          or there is an overflow in the sum of index and count.
     * @param tokenType The token type
     * @param index The offset of the list
     * @param count The number of tokens to retrieve
     * @return An array of token addresses belonging to `tokenType`
     */
    function listTokensByIndexAndCount(uint8 tokenType, uint256 index, uint256 count) external view virtual returns (address[] memory) {
        EnumerableSet.AddressSet storage tokenSet = _typeTokens[tokenType];
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

    // ============================== PUBLIC FUNCTIONS ===========================

    /**
     * @notice Checks whether `token` is in the pool
     */
    function isTokenInPool(address token) public view virtual returns (bool) {
        return _isTokenTypeValid(_tokenType[token]);
    }

    /**
     * @notice Gets the token count by `tokenType`
     */
    function tokenLength(uint8 tokenType) public view virtual returns (uint256) {
        return _typeTokens[tokenType].length();
    }

    /**
     * @notice Gets the token address by `tokenType` and `index`
     */
    function tokenByIndex(uint8 tokenType, uint256 index) public view virtual returns (address) {
        return _typeTokens[tokenType].at(index);
    }

    // ============================== INTERNAL FUNCTIONS ===========================

    /**
     * @notice Adds the token to the pool
     * @param token Address of the token
     * @param tokenType The value of the token type
     */
    function _addToken(address token, uint8 tokenType) internal virtual tokenNotInPool(token) {
        AddressUtils.checkContract(token);
        _require(_isTokenTypeValid(tokenType), Errors.TOKEN_TYPE_INVALID);

        _require(_typeTokens[tokenType].add(token), Errors.TOKEN_ALREADY_EXISTS);

        _tokenType[token] = tokenType;

        emit TokenAdded(token, tokenType);
    }

    /**
     * @notice Removes the token from the pool
     * @param token Address of the token
     */
    function _removeToken(address token) internal virtual tokenInPool(token) {
        uint8 tokenType = _tokenType[token];

        _require(_typeTokens[tokenType].remove(token), Errors.TOKEN_NOT_EXISTS);

        delete (_tokenType[token]);

        emit TokenRemoved(token, tokenType);
    }

    /**
     * @notice Checks whether `tokenType` is valid
     */
    function _isTokenTypeValid(uint8 tokenType) internal pure virtual returns (bool);
}
