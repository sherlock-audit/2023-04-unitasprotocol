// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IInsurancePool.sol";
import "../src/utils/Errors.sol";
import "./PoolBalances.sol";

contract InsurancePool is AccessControl, ReentrancyGuard, IInsurancePool, PoolBalances {
    using SafeERC20 for IERC20;

    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");
    bytes32 public constant TIMELOCK_ROLE = keccak256("TIMELOCK_ROLE");
    bytes32 public constant PORTFOLIO_ROLE = keccak256("PORTFOLIO_ROLE");

    /**
     * @notice Emitted when `amount` of `token` is received from `sender`
     */
    event CollateralDeposited(address indexed token, address indexed sender, uint256 amount);
    /**
     * @notice Emitted when `amount` of `token` is sent to `receiver`
     */
    event CollateralWithdrawn(address indexed token, address indexed receiver, uint256 amount);

    error NotGuardian(address caller);
    error NotWithdrawer(address caller);
    error NotTimelock(address caller);
    error NotPortfolio(address caller);

    modifier onlyGuardian() {
        if (!hasRole(GUARDIAN_ROLE, msg.sender))
            revert NotGuardian(msg.sender);
        _;
    }

    modifier onlyGuardianOrWithdrawer() {
        if (!hasRole(GUARDIAN_ROLE, msg.sender) && !hasRole(WITHDRAWER_ROLE, msg.sender))
            revert NotWithdrawer(msg.sender);
        _;
    }

    /**
     * @notice Reverts if `msg.sender` does not have `TIMELOCK_ROLE`
     */
    modifier onlyTimelock() {
        if (!hasRole(TIMELOCK_ROLE, msg.sender))
            revert NotTimelock(msg.sender);
        _;
    }

    /**
     * @notice Reverts if `account` does not have `PORTFOLIO_ROLE`
     */
    modifier onlyPortfolio(address account) {
        if (!hasRole(PORTFOLIO_ROLE, account)) {
            revert NotPortfolio(account);
        }
        _;
    }

    constructor(address governor_, address guardian_, address timelock_) {
        _setRoleAdmin(GOVERNOR_ROLE, GOVERNOR_ROLE);
        _setRoleAdmin(GUARDIAN_ROLE, GUARDIAN_ROLE);
        _setRoleAdmin(WITHDRAWER_ROLE, GUARDIAN_ROLE);
        _setRoleAdmin(TIMELOCK_ROLE, GOVERNOR_ROLE);
        _setRoleAdmin(PORTFOLIO_ROLE, GUARDIAN_ROLE);

        _grantRole(GOVERNOR_ROLE, governor_);
        _grantRole(GUARDIAN_ROLE, guardian_);
        _grantRole(TIMELOCK_ROLE, timelock_);
        _grantRole(PORTFOLIO_ROLE, guardian_);
    }

    /**
     * @notice Deposits the collateral from the sender
     * @param token Address of the token
     * @param amount Amount of the collateral
     */
    function depositCollateral(address token, uint256 amount) external onlyGuardian nonReentrant {
        _checkAmountPositive(amount);

        _setBalance(token, _getBalance(token) + amount);

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit CollateralDeposited(token, msg.sender, amount);
    }

    /**
     * @notice Withdraws the collateral to the sender
     * @param token Address of the token
     * @param amount Amount of the collateral
     */
    function withdrawCollateral(address token, uint256 amount) external onlyGuardianOrWithdrawer nonReentrant {
        _checkAmountPositive(amount);

        uint256 collateral = _getBalance(token);
        _require(collateral - _getPortfolio(token) >= amount, Errors.POOL_BALANCE_INSUFFICIENT);

        _setBalance(token, collateral - amount);

        IERC20(token).safeTransfer(msg.sender, amount);

        emit CollateralWithdrawn(token, msg.sender, amount);
    }

    /**
     * @notice Receives the portfolio from the sender
     * @param token Address of the token
     * @param amount Amount of the portfolio
     */
    function receivePortfolio(address token, uint256 amount)
        external
        onlyPortfolio(msg.sender)
        nonReentrant
    {
        _receivePortfolio(token, msg.sender, amount);
    }

    /**
     * @notice Sends the portfolio to the receiver
     * @param token Address of the token
     * @param receiver Account to receive the portfolio
     * @param amount Amount of the portfolio
     */
    function sendPortfolio(address token, address receiver, uint256 amount)
        external
        onlyTimelock
        onlyPortfolio(receiver)
        nonReentrant
    {
        _sendPortfolio(token, receiver, amount);
    }

    /**
     * @notice Gets the collateral of `token`
     */
    function getCollateral(address token) public view returns (uint256) {
        return _getBalance(token);
    }

    /**
     * @notice Gets the portfolio of `token`
     */
    function getPortfolio(address token) public view returns (uint256) {
        return _getPortfolio(token);
    }
}