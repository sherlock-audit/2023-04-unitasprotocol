// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/IERC20Token.sol";
import "./interfaces/ITokenManager.sol";
import "./utils/Errors.sol";
import "./TokenPairs.sol";
import "./TypeTokens.sol";

/**
 * @title TokenManager
 * @notice This contract is responsible for managing tokens and pairs,
 *          and it stores all of the settings related to them.
 */
contract TokenManager is AccessControl, TypeTokens, TokenPairs, ITokenManager {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant TIMELOCK_ROLE = keccak256("TIMELOCK_ROLE");

    /**
     * @notice The denominator of reserve ratio and threshold that has 18 decimals
     */
    uint256 public constant RESERVE_RATIO_BASE = 1e18;
    /**
     * @notice The denominator of swapping fee that has 6 decimals
     */
    uint256 public constant SWAP_FEE_BASE = 1e6;

    /**
     * @notice Maximum price tolerances
     * @dev Address of the token => max price tolerance
     */
    mapping(address => uint256) internal _maxPriceTolerance;
    /**
     * @notice Minimum price tolerances
     * @dev Address of the token => min price tolerance
     */
    mapping(address => uint256) internal _minPriceTolerance;
    /**
     * @notice Maps the pair hash to `PairConfig` that contains two token addresses, fee numerators and reserve ratio thresholds
     */
    mapping(bytes32 => PairConfig) internal _pair;

    IERC20Token public usd1;

    /**
     * @notice Emitted when the setting of the pair is updated
     */
    event PairUpdated(
        bytes32 indexed pairHash,
        address indexed baseToken,
        address indexed quoteToken,
        uint24 buyFee,
        uint232 buyReserveRatioThreshold,
        uint24 sellFee,
        uint232 sellReserveRatioThreshold
    );

    error NotTimelock(address caller);

    /**
     * @notice Reverts if `msg.sender` does not have `TIMELOCK_ROLE`
     */
    modifier onlyTimelock() {
        if (!hasRole(TIMELOCK_ROLE, msg.sender)) {
            revert NotTimelock(msg.sender);
        }
        _;
    }

    constructor(
        address governor_,
        address timelock_,
        address usd1_,
        TokenConfig[] memory tokens_,
        PairConfig[] memory pairs_
    ) {
        _setRoleAdmin(GOVERNOR_ROLE, GOVERNOR_ROLE);
        _setRoleAdmin(TIMELOCK_ROLE, GOVERNOR_ROLE);

        _grantRole(GOVERNOR_ROLE, governor_);
        _grantRole(TIMELOCK_ROLE, timelock_);

        _setUSD1(usd1_);
        _addTokensAndPairs(tokens_, pairs_);
    }

    /**
     * @notice Updates the address of `usd1` to `token`, and adds it to the pool with stable type.
     *          Before calling this function, the pairs associated with the old token must be removed.
     */
    function setUSD1(address token) external onlyTimelock {
        _setUSD1(token);
    }

    /**
     * @notice Updates the price tolerance range of USD1/`token`
     * @param token Address of the quote currency
     * @param minPrice Min price tolerance
     * @param maxPrice Max price tolerance
     */
    function setMinMaxPriceTolerance(address token, uint256 minPrice, uint256 maxPrice) external onlyTimelock {
        _setMinMaxPriceTolerance(token, minPrice, maxPrice);
    }

    /**
     * @notice Adds the tokens and the pairs to the pool.
     *         The input arrays can be empty, and the update is performed only
     *         when either `tokens` or `pairs` array has values.
     * @param tokens The settings of the tokens to be added
     * @param pairs The settings of the pairs to be added
     */
    function addTokensAndPairs(TokenConfig[] calldata tokens, PairConfig[] calldata pairs) external onlyTimelock {
        _addTokensAndPairs(tokens, pairs);
    }

    /**
     * @notice Removes the tokens and the pairs from the pool.
     *          The input arrays can be empty, and the update is performed only
     *          when either `tokens`, or `pairTokensX` and `pairTokensY` have values.
     *          Since `_removeToken` checks there must be no pairs associated with the token,
     *          removes the pairs before the tokens.
     * @param tokens The addresses of the tokens to be removed
     * @param pairTokensX The addresses of the base tokens or quote tokens to be removed
     * @param pairTokensY The addresses of the base tokens or quote tokens to be removed.
     *         The length of `pairTokensX` and `pairTokensY` must be the same.
     */
    function removeTokensAndPairs(
        address[] calldata tokens,
        address[] calldata pairTokensX,
        address[] calldata pairTokensY
    ) external onlyTimelock {
        _require(pairTokensX.length == pairTokensY.length, Errors.ARRAY_LENGTH_MISMATCHED);

        uint256 tokenCount = tokens.length;
        uint256 pairCount = pairTokensX.length;

        for (uint256 i; i < pairCount; i++) {
            _removePair(pairTokensX[i], pairTokensY[i]);
        }

        for (uint256 i; i < tokenCount; i++) {
            _removeToken(tokens[i]);
        }
    }

    /**
     * @notice Updates the settings of the pairs,
     *          reverts if any pair of the array is invalid or not in the pool.
     * @param pairs The settings of the pairs
     */
    function updatePairs(PairConfig[] calldata pairs) external onlyTimelock {
        uint256 pairCount = pairs.length;

        for (uint256 i; i < pairCount; i++) {
            _updatePair(pairs[i]);
        }
    }

    /**
     * @notice Gets an array of pair settings, supporting pagination.
     *          Reverts if the index plus the count is out of bounds,
     *          or there is an overflow in the sum of index and count.
     * @param index The offset of the list
     * @param count The number of pairs to retrieve
     * @return An array of `PairConfig`
     */
    function listPairsByIndexAndCount(uint256 index, uint256 count) external view returns (PairConfig[] memory) {
        uint256 pairCount = _pairHashes.length();

        _require(
            (index == 0 || index < pairCount) && index + count <= pairCount,
            Errors.INPUT_OUT_OF_BOUNDS
        );

        PairConfig[] memory pairs = new PairConfig[](count);

        for (uint256 i; i < count; i++) {
            pairs[i] = _pair[_pairHashes.at(index + i)];
        }

        return pairs;
    }

    /**
     * @notice Gets the price tolerance of `token`
     */
    function getPriceTolerance(address token) public view returns (uint256 minPrice, uint256 maxPrice) {
        minPrice = _minPriceTolerance[token];
        maxPrice = _maxPriceTolerance[token];
    }

    /**
     * @notice Gets the token type of `token`
     */
    function getTokenType(address token) public view returns (TokenType) {
        return TokenType(_tokenType[token]);
    }

    /**
     * @notice Gets the pair setting by two token addresses, reverts if the pair does not exist.
     * @param tokenX Address of base currency or quote currency
     * @param tokenY Address of base currency or quote currency
     * @return pair The setting of the pair
     */
    function getPair(address tokenX, address tokenY) public view returns (PairConfig memory pair) {
        (tokenX, tokenY) = _sortTokens(tokenX, tokenY);

        return _pair[_checkPairExists(tokenX, tokenY)];
    }

    /**
     * @notice Gets the pair setting by `index`
     */
    function pairByIndex(uint256 index) public view returns (PairConfig memory pair) {
        return _pair[_pairHashes.at(index)];
    }

    function _setUSD1(address token) internal {
        address oldToken = address(usd1);
        if (oldToken != address(0)) {
            _removeToken(oldToken);
        }

        _addToken(token, uint8(TokenType.Stable));
        usd1 = IERC20Token(token);
    }

    function _setMinMaxPriceTolerance(address token, uint256 minPrice, uint256 maxPrice) internal {
        _require(maxPrice != 0, Errors.MAX_PRICE_INVALID);
        _require(minPrice != 0 && minPrice <= maxPrice, Errors.MIN_PRICE_INVALID);
        _maxPriceTolerance[token] = maxPrice;
        _minPriceTolerance[token] = minPrice;
    }

    /**
     * @notice Adds the tokens and the pairs to the pool.
     *          Since `_addPair` checks whether the token is already in the pool,
     *          adds the tokens before the pairs.
     */
    function _addTokensAndPairs(TokenConfig[] memory tokens, PairConfig[] memory pairs) internal {
        uint256 tokenCount = tokens.length;
        uint256 pairCount = pairs.length;

        for (uint256 i; i < tokenCount; i++) {
            TokenConfig memory token = tokens[i];
            _addToken(token.token, uint8(token.tokenType));
            _setMinMaxPriceTolerance(token.token, token.minPrice, token.maxPrice);
        }

        for (uint256 i; i < pairCount; i++) {
            _addPair(pairs[i]);
        }
    }

    /**
     * @notice Removes the token from the pool.
     *          The pairs associated with the token must be removed first.
     * @param token Address of the token
     */
    function _removeToken(address token) internal override {
        _require(pairTokenLength(token) == 0, Errors.PAIRS_MUST_REMOVED);

        super._removeToken(token);

        if (token == address(usd1)) {
            usd1 = IERC20Token(address(0x0));
        }
    }

    /**
     * @notice Adds the pair to the pool.
     *          Reverts if the setting is invalid, two tokens are not in the pool,
     *          or the pair is already in the pool.
     * @param pair The setting of the pair
     */
    function _addPair(PairConfig memory pair) internal {
        _checkPairParameters(pair);

        (address tokenX, address tokenY) = _sortTokens(pair.baseToken, pair.quoteToken);
        bytes32 pairHash = _addPairByTokens(tokenX, tokenY);

        _pair[pairHash] = pair;

        emit PairUpdated(
            pairHash,
            pair.baseToken,
            pair.quoteToken,
            pair.buyFee,
            pair.buyReserveRatioThreshold,
            pair.sellFee,
            pair.sellReserveRatioThreshold
        );
    }

    /**
     * @notice Updates the pair setting.
     *          Reverts if the setting is invalid, two tokens are not in the pool,
     *          or the pair is not in the pool.
     * @param pair The setting of the pair
     */
    function _updatePair(PairConfig memory pair) internal {
        _checkPairParameters(pair);

        (address tokenX, address tokenY) = _sortTokens(pair.baseToken, pair.quoteToken);
        bytes32 pairHash = _checkPairExists(tokenX, tokenY);

        _pair[pairHash] = pair;

        emit PairUpdated(
            pairHash,
            pair.baseToken,
            pair.quoteToken,
            pair.buyFee,
            pair.buyReserveRatioThreshold,
            pair.sellFee,
            pair.sellReserveRatioThreshold
        );
    }

    /**
     * @notice Removes the pair and the setting, reverts if the pair doesn't exist.
     * @param tokenX Address of base currency or quote currency
     * @param tokenY Address of base currency or quote currency
     */
    function _removePair(address tokenX, address tokenY) internal {
        (tokenX, tokenY) = _sortTokens(tokenX, tokenY);

        bytes32 pairHash = _removePairByTokens(tokenX, tokenY);

        delete _pair[pairHash];
    }

    /**
     * @notice Checks whether the parameters of `pair` are valid.
     *          The two tokens must be added to the pool before adding the pair.
     *          It validates the two token addresses are not the same,
     *          and one of the tokens must be USD1.
     *          It also validates the fee numerators and the reserve ratio thresholds.
     */
    function _checkPairParameters(PairConfig memory pair)
        internal
        view
        tokenInPool(pair.baseToken)
        tokenInPool(pair.quoteToken)
    {
        _require(pair.baseToken != pair.quoteToken, Errors.PAIR_INVALID);

        address usd1Address = address(usd1);
        _require(usd1Address != address(0), Errors.USD1_NOT_SET);
        _require(pair.baseToken == usd1Address || pair.quoteToken == usd1Address, Errors.PAIR_INVALID);

        _checkSwapFeeNumerator(pair.buyFee);
        _checkReserveRatioThreshold(pair.buyReserveRatioThreshold);

        _checkSwapFeeNumerator(pair.sellFee);
        _checkReserveRatioThreshold(pair.sellReserveRatioThreshold);
    }

    /**
     * @notice Checks whether `tokenType` is valid
     */
    function _isTokenTypeValid(uint8 tokenType) internal pure override returns (bool) {
        return tokenType == uint8(TokenType.Asset) || tokenType == uint8(TokenType.Stable);
    }

    /**
     * @notice Checks whether the swapping fee numerator is valid
     * @param feeNumerator The fee numerator with 6 decimals. It must be less than the denominator.
     */
    function _checkSwapFeeNumerator(uint24 feeNumerator) internal pure {
        _require(feeNumerator < SWAP_FEE_BASE, Errors.FEE_NUMERATOR_INVALID);
    }

    /**
     * @notice Checks whether the reserve ratio threshold is valid
     * @param reserveRatioThreshold The threshold with 18 decimals, zero indicates unlimited.
     *                               It must be zero or greater than or equal to 1e18 (100%).
     */
    function _checkReserveRatioThreshold(uint232 reserveRatioThreshold) internal pure {
        _require(
            reserveRatioThreshold == 0 || reserveRatioThreshold >= RESERVE_RATIO_BASE,
            Errors.RESERVE_RATIO_THRESHOLD_INVALID
        );
    }
}
