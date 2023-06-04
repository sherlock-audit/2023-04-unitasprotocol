
# Unitas Protocol contest details

- Join [Sherlock Discord](https://discord.gg/MABEWyASkp)
- Submit findings using the issue page in your private contest repo (label issues as med or high)
- [Read for more details](https://docs.sherlock.xyz/audits/watsons)

# Q&A

### Q: On what chains are the smart contracts going to be deployed?
Ethreum mainnet
___

### Q: Which ERC20 tokens do you expect will interact with the smart contracts? 
USDT 
___

### Q: Which ERC721 tokens do you expect will interact with the smart contracts? 
None
___

### Q: Which ERC777 tokens do you expect will interact with the smart contracts? 
None
___

### Q: Are there any FEE-ON-TRANSFER tokens interacting with the smart contracts?

No
___

### Q: Are there any REBASING tokens interacting with the smart contracts?

No
___

### Q: Are the admins of the protocols your contracts integrate with (if any) TRUSTED or RESTRICTED?
TRUSTED
___

### Q: Is the admin/owner of the protocol/contracts TRUSTED or RESTRICTED?
TRUSTED
___

### Q: Are there any additional protocol roles? If yes, please explain in detail:
* MINTER_ROLE (Unitas contract)
* TIMELOCK_ROLE (OZ Contract)
   * TIMELOCK's admin == (GOVERNOR_ROLE)
* FEEDER_ROLE (EOA)
* GOVERNOR_ROLE (Multisig wallet)
* GUARDIAN_ROLE (Multisig wallet)
* PORTFOLIO_ROLE (Multisig wallet)
* WITHDRAWER_ROLE (Unitas contract)
* ProxyAdmin (OZ Contract)
* ProxyAdmin's admin (GUARDIAN_ROLE)
___

### Q: Is the code/contract expected to comply with any EIPs? Are there specific assumptions around adhering to those EIPs that Watsons should be aware of?
None
___

### Q: Please list any known issues/acceptable risks that should not result in a valid finding.
1. [OpenZeppelin #4154 Fix TransparentUpgradeableProxy's transparency](https://github.com/OpenZeppelin/openzeppelin-contracts/pull/4154)
   - Risk: very low.

2. In Xoracle, there is no milliseconds check, so potential can bypass the `require(prev_timestamp < timestamp, "Outdated timestamp");` and update the price on the same date.  If the frontend fetches the timestamp of price updates, it will only lead to confusion.
   - Risk: very low.
   
3. When users are performing a swap, if they encounter an Oracle price update within the same block, they may exchange at a different price than originally expected. Our Oracle price feeder does not have a fixed update time, but the chances of encountering this situation are very low. We plan to implement checks in phase 2 to address this.
   - Risk: very low.
___

### Q: Please provide links to previous audits (if any).
NA
___

### Q: Are there any off-chain mechanisms or off-chain procedures for the protocol (keeper bots, input validation expectations, etc)?
Oracle feeder 
___

### Q: In case of external protocol integrations, are the risks of external contracts pausing or executing an emergency withdrawal acceptable? If not, Watsons will submit issues related to these situations that can harm your protocol's functionality.
No external contracts integration 
___



# Audit scope


[Unitas-Protocol @ 9ef6847c5437bfe5e178355f36f9ebb19c1d0468](https://github.com/xrex-inc/Unitas-Protocol/tree/9ef6847c5437bfe5e178355f36f9ebb19c1d0468)
- [Unitas-Protocol/src/ERC20Token.sol](Unitas-Protocol/src/ERC20Token.sol)
- [Unitas-Protocol/src/InsurancePool.sol](Unitas-Protocol/src/InsurancePool.sol)
- [Unitas-Protocol/src/PoolBalances.sol](Unitas-Protocol/src/PoolBalances.sol)
- [Unitas-Protocol/src/SwapFunctions.sol](Unitas-Protocol/src/SwapFunctions.sol)
- [Unitas-Protocol/src/TimelockController.sol](Unitas-Protocol/src/TimelockController.sol)
- [Unitas-Protocol/src/TokenManager.sol](Unitas-Protocol/src/TokenManager.sol)
- [Unitas-Protocol/src/TokenPairs.sol](Unitas-Protocol/src/TokenPairs.sol)
- [Unitas-Protocol/src/TypeTokens.sol](Unitas-Protocol/src/TypeTokens.sol)
- [Unitas-Protocol/src/Unitas.sol](Unitas-Protocol/src/Unitas.sol)
- [Unitas-Protocol/src/UnitasProxy.sol](Unitas-Protocol/src/UnitasProxy.sol)
- [Unitas-Protocol/src/UnitasProxyAdmin.sol](Unitas-Protocol/src/UnitasProxyAdmin.sol)
- [Unitas-Protocol/src/XOracle.sol](Unitas-Protocol/src/XOracle.sol)
- [Unitas-Protocol/src/interfaces/IERC20Token.sol](Unitas-Protocol/src/interfaces/IERC20Token.sol)
- [Unitas-Protocol/src/interfaces/IInsurancePool.sol](Unitas-Protocol/src/interfaces/IInsurancePool.sol)
- [Unitas-Protocol/src/interfaces/IOracle.sol](Unitas-Protocol/src/interfaces/IOracle.sol)
- [Unitas-Protocol/src/interfaces/ISwapFunctions.sol](Unitas-Protocol/src/interfaces/ISwapFunctions.sol)
- [Unitas-Protocol/src/interfaces/ITokenManager.sol](Unitas-Protocol/src/interfaces/ITokenManager.sol)
- [Unitas-Protocol/src/interfaces/ITokenPairs.sol](Unitas-Protocol/src/interfaces/ITokenPairs.sol)
- [Unitas-Protocol/src/interfaces/ITypeTokens.sol](Unitas-Protocol/src/interfaces/ITypeTokens.sol)
- [Unitas-Protocol/src/interfaces/IUnitas.sol](Unitas-Protocol/src/interfaces/IUnitas.sol)
- [Unitas-Protocol/src/utils/AddressUtils.sol](Unitas-Protocol/src/utils/AddressUtils.sol)
- [Unitas-Protocol/src/utils/Errors.sol](Unitas-Protocol/src/utils/Errors.sol)
- [Unitas-Protocol/src/utils/ScalingUtils.sol](Unitas-Protocol/src/utils/ScalingUtils.sol)


