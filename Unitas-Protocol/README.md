## Table of Contents

*  [Architecture Overview](#architecture-overview)
*  [Audit Scope](#audit-scope)
*  [Role management](#role-management)
*  [Multisig wallet](#multisig-wallet---gnosis-safe)
*  [Known issue](#known-issue)
*  [Building](#building)
*  [Contract Functions](#contract-functions)
    * [Unitas](#unitas)
    * [InsurancePool](#insurancepool)
    * [Typetokens](#typetokens)
    * [TokenPairs](#tokenpairs)
    * [SwapFunctions](#swapfunctions)
    * [XOracle](#xoracle)
* [Why Unitas?](#why-unitas)
* [Unitas White Paper](#unitas-white-paper)
* [Unitas Features](#unitas-features)
    * [Minting](#minting)
    * [Burn/Redeem](#burnredeem)
    * [Oracle: Phase1](#oracle-phase1)
* [Risk Management](#risk-management)

# Architecture Overview
![Unitas Protocol V1](https://github.com/xrex-inc/Unitas-audit/assets/52526645/ecb21a5f-6916-456e-aa2e-17ad5765001a)

## Audit Scope
![nSLOC](https://github.com/xrex-inc/Unitas-audit/assets/52526645/d86c962a-4465-4cef-bd45-d052d54ee647)

**ERC20Token.sol**: ERC20 contract + ( Blacklist + AccessControl + Pausable)

**Unitas.sol**: core contract, this contract is primarily used for exchanging tokens, managing reserve assets.
  
**InsurancePool.sol**: The funds in our first phase InsurancePool are all contributed by Unitas. So this contract is just a simple vault. The auction module will be supported in the second phase.

**SwapFunctions.sol**: This is an abstract contract called SwapFunctions that implements the ISwapFunctions interface. It defines several functions for calculating swapping results, including calculating fees, converting amounts, and validating fees. These functions are implemented using the MathUpgradeable library from OpenZeppelin. 

**TokenManager.sol**: This contract is responsible for managing currency pairs that are open for swapping, and setting parameters such as swapping fees and reserve ratio thresholds.
  - TokenType.Asset: USDT (Phase1), USDC (TBD). **Deflationary token is not supported.**
  - TokenType.Stable: USD1, USD91, USD971, USD886 and USD84. All EMC tokens decimal is 18.

**TypeTokens.sol**: This is an abstract contract called TypeTokens that implements the ITypeTokens interface. It includes mappings for storing token types and token addresses, and events for adding or removing tokens from the pool. The contract also defines two modifiers for checking if a token is already in the pool or not.

**TokenPairs.sol**: This abstract contract implements the ITokenPairs interface. It is used to manage pairs, including the enumerable functionality.

**PoolBalances.sol**: This is an abstract contract includes some generic functions that are used to manage pool assets. It includes mappings for storing token balances and token portfolios, and events are emitted when portfolios change.

**XOracle.sol**: this contract is an oracle that provides price data for various assets. It allows addresses with the "FEEDER_ROLE" to update the prices of assets and anyone to view the current and previous prices. The "GUARDIAN_ROLE" is a role with higher permissions than the "FEEDER_ROLE" and is used for administrative purposes such as adding or removing feeders.

**UnitasProxy.sol**: Transparent Proxy

**UnitasProxyAdmin.sol**: ProxyAdmin

**TimelockController.sol (OpenZeppelin Contracts)**: The TimelockController is configured with a time delay of 24/48 hours. This means that any proposed transactions or function calls through the TimelockController must be scheduled in advance and will only be executed after a waiting period of 24/48 hours. (Only calls from the GOVERNOR_ROLE are allowed.)
   - We will monitor the execution of Timelock functions on-chain and send notifications to the Unitas Telegram channel or any official Unitas channel, informing everyone about the operation.


## Role management: 

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

### Multisig wallet - Gnosis Safe
* GUARDIAN_ROLE 2 of 3
* PORTFOLIO_ROLE 2 of 3
* GOVERNOR_ROLE (DAO) 4 of 7
  * Phase 1: 2 of 3
  * Phase2: 4 of 7
 
we will use the GOVERNOR multi-signature wallet as the SurplusPool in phase1. All protocol transaction fees will be sent to the surplus pool.

In phase 1, as the Insurance Pool does not yet support the auction module, the Unitas Foundation will act as an Insurance Provider (IP) for staking/unstaking USDT. This can be done through the depositCollateral/withdrawCollateral functions, using only the Guardian (multi-signature wallet).

The sendPortfolio function perform a timelock for 24 hours to transfer a portion of the funds to the portfolio wallet (multi-signature wallet) for DeFi staking investments.

### Known issue:
1. [OpenZeppelin #4154 Fix TransparentUpgradeableProxy's transparency](https://github.com/OpenZeppelin/openzeppelin-contracts/pull/4154)
   - Risk: very low.

2. In Xoracle, there is no milliseconds check, so potential can bypass the `require(prev_timestamp < timestamp, "Outdated timestamp");` and update the price on the same date.  If the frontend fetches the timestamp of price updates, it will only lead to confusion.
   - Risk: very low.
   
3. When users are performing a swap, if they encounter an Oracle price update within the same block, they may exchange at a different price than originally expected. Our Oracle price feeder does not have a fixed update time, but the chances of encountering this situation are very low. We plan to implement checks in phase 2 to address this.
   - Risk: very low.

## Prerequisites

* Installs <a href="https://github.com/foundry-rs/foundry" target="_blank">Foundry</a>

## Building

Builds smart contracts with outputting ABI files.

```bash
forge build --force --extra-output-files abi
```

## Testing

Executes tests and prints a gas report.

```bash
forge test --gas-report
```

----
# Contract Functions

## Unitas

Inherits **Initializable**, **PausableUpgradeable**, **AccessControlUpgradeable**, **ReentrancyGuardUpgradeable**, **PoolBalances** and **SwapFunctions**.  
The contract is upgradeable.

#### State Variables
    
- **usd1**: Gets the address of USD1
- **oracle**: Gets the address of oracle
- **surplusPool**: Gets the address of surplus pool (treasury)
- **insurancePool**: Gets the address of insurance pool
- **tokenManager**: Gets the address of token manager

#### Modifiers

- **onlyTimelock**: This modifier is used to restrict access to a function to only the address that has the TIMELOCK_ROLE. If the msg.sender does not have the TIMELOCK_ROLE, the function will revert with the NotTimelock error.

- **onlyGuardian**: This modifier is used to restrict access to a function to only the address that has the GUARDIAN_ROLE. If the msg.sender does not have the GUARDIAN_ROLE, the function will revert with the NotGuardian error.

- **onlyPortfolio**: This modifier is used to restrict access to a function based on a specific address having the PORTFOLIO_ROLE. The address of the portfolio is passed as an argument to the modifier. If the provided account does not have the PORTFOLIO_ROLE, the function will revert with the NotPortfolio error.

#### Public or External Functions

- **initialize**: Initializes the states when deploying the proxy contract, e.g., access control, dependent contract addresses. (initializer restriction)
- **swap**: Swaps tokens between USD-Pegs, USD1 or USD-EMCs. Users can choose to input the amount to be spent or the amount to be received. The function will check oracle price is in the tolerance range, checks the reserve ratio is sufficient when there has a limitation. It will update the reserve of the token when the user spends or redeems USD-Pegs, and it will send fee to the surplus pool
- **estimateSwapResult**: Estimates the swap result for quoting. It will return the amount to spent, the amount to receive, the fee, the numerator of fee ratio, and the price
- **getReserve**: Gets current reserve of the token
- **getReserveStatus**: Gets the reserve status, total reserves denominated in USD1, total collaterals denominated in USD1, total liabilities denominated in USD1, and the reserve ratio
- **getPortfolio**: Gets the portfolio state of the token

#### Timelock Functions

- **setOracle**: Updates the address of oracle
- **setSurplusPool**: Updates the address of surplus pool
- **setInsurancePool**: Updates the address of insurance pool
- **setTokenManager**: Updates the address of token manager
- **sendPortfolio**: Transfers the tokens from the pool to the portfolio manager

#### Guardian Functions

- **pause**: Disables swapping
- **unpause**: Enables swapping

#### Portfolio Functions

- **receivePortfolio**: Transfers the tokens from the portfolio manager to the pool

#### Internal or Private Functions

- **_setOracle**: Updates the address of oracle
- **_setSurplusPool**: Updates the address of surplus pool
- **_setInsurancePool**: Updates the address of insurance pool
- **_setTokenManager**: Updates the address of token manager
- **_setReserve**: Updates the reserve of the token
- **_swapIn**: Transfers USD-Pegs to the pool, or burns Unitas stablecoins from the user
- **_swapOut**: Transfers USD-Pegs or mints Unitas stablecoins to the user
- **_getSwapResult**: Gets the swap result
- **_getReserveStatus**: Calculates the reserve ratio by reserves and liabilities, returns the reserve status and the reserve ratio
- **_getTotalReservesAndCollaterals**: Gets total reserves and total collaterals denominated in USD1
- **_getTotalLiabilities**: Gets total liabilities denominated in USD1
- **_getPriceQuoteToken**: Gets the quote currency based on two token address parameters
- **_checkPrice**: Reverts when the price tolerance range of the token is unset, or the price is not in the tolerance range
- **_checkReserveRatio**: When the reserve ratio threshold of the swap type is positive, checks the reserve ratio is greater than the threshold

## InsurancePool

Inherits **AccessControl** and **ReentrancyGuard** and **PoolBalances**.

#### Modifiers

- **onlyGuardian**: This modifier is used to restrict access to a function to only the address that has the GUARDIAN_ROLE. If the msg.sender does not have the GUARDIAN_ROLE, the function will revert with the NotGuardian error.

- **onlyGuardianOrWithdrawer**: This modifier allows access to a function for addresses that have either the GUARDIAN_ROLE or the WITHDRAWER_ROLE. If the msg.sender does not have either of these roles, the function will revert with the NotWithdrawer error.

- **onlyTimelock**: This modifier restricts access to a function to only the address that has the TIMELOCK_ROLE. If the msg.sender does not have the TIMELOCK_ROLE, the function will revert with the NotTimelock error.

- **onlyPortfolio**: This modifier restricts access to a function based on a specific address having the PORTFOLIO_ROLE. The address of the portfolio is passed as an argument to the modifier. If the provided account does not have the PORTFOLIO_ROLE, the function will revert with the NotPortfolio error.


#### Public or External Functions

- **getCollateral**: Gets current collateral of the token
- **getPortfolio**: Gets the portfolio state of the token

#### Guardian Functions

- **depositCollateral**: Puts the collateral for a given token to the pool

#### Guardian or Withdrawer Functions

- **withdrawCollateral**: Withdraws the collateral of the token from the pool. The guardian can withdraw the collateral, and Unitas contract (withdrawer) will withdraw the collateral when the reserve is insufficient to redeem

#### Timelock Functions

- **sendPortfolio**: Transfers the tokens from the pool to the portfolio manager

#### Portfolio Functions

- **receivePortfolio**: Transfers the tokens from the portfolio manager to the pool

## TokenManager

Inherits **AccessControl**, **TypeTokens**, **TokenPairs**.

#### State Variables

- **RESERVE_RATIO_BASE**: Returns 10<sup>18</sup>. The denominator of reserve ratio and threshold that have 18 decimal places
- **SWAP_FEE_BASE**: Returns 10<sup>6</sup>. The denominator of swapping fee that has 6 decimal places
- **_maxPriceTolerance**: This is a mapping that associates an address of a token with its corresponding maximum price tolerance. It is used to store the maximum price tolerance for each token.
- **_minPriceTolerance**: This is a mapping that associates an address of a token with its corresponding minimum price tolerance. It is used to store the minimum price tolerance for each token.
- **_pair**: This is a mapping that associates a pair hash with a PairConfig object. The PairConfig contains two token addresses, fee numerators and reserve ratio thresholds
- **usd1**: Gets the address of USD1

#### Modifiers

- **onlyTimelock**: This modifier is used to restrict access to a function to only the address that has the TIMELOCK_ROLE. If the msg.sender does not have the TIMELOCK_ROLE, the function will revert with the NotTimelock error.

#### Public or External Functions

- **listPairsByIndexAndCount**: Gets an array of PairConfig, supporting pagination
- **getPriceTolerance**: Gets the price tolerance range of the token
- **getTokenType**: Gets the type of the token. There has two types of tokens, `Asset` (USD-Pegs) for calculating reserves, `Stable` (USD1, USD91 and USD971) for calculating liabilities
- **getPair**: Gets the pair setting by the two token addresses. Reverts if the pair does not exist
- **pairByIndex**: Gets the pair setting by the index of pair hashes

#### Timelock Functions

- **setUSD1**: Updates the address of USD1, and adds it to the pool as stablecoin
- **setMinMaxPriceTolerance**: Updates the price tolerance range of the token
- **addTokensAndPairs**: Adds the tokens and the pairs to the pool. The input arrays can be empty, and the update is performed only when any array has values
- **removeTokensAndPairs**: Removes the tokens and the pairs from the pool. The input arrays can be empty, and the update is performed only when the tokens array, or the two arrays of pair token addresses have values
- **updatePairs**: Updates the pair settings based on the input array of PairConfig. Reverts if any PairConfig is invalid or not in the pool

#### Internal or Private Functions

- **_setUSD1**: Updates the address of USD1, and adds it to the pool as stablecoin
- **_setMinMaxPriceTolerance**: Updates the price tolerance range of the token
- **_addTokensAndPairs**: Adds the tokens and the pairs to the pool. Since `_addPair` checks whether the token is already in the pool, this function adds the tokens before the pairs
- **_removeToken**: Removes the token from the pool. The pairs associated with the token must be removed first
- **_addPair**: Adds the pair to the pool. Reverts if the PairConfig is invalid, two tokens are not in the pool, or the pair is already in the pool
- **_updatePair**: Updates the pair setting by PairConfig. Reverts if the PairConfig is invalid, two tokens are not in the pool, or the pair is not in the pool
- **_removePair**: Removes the pair and the PairConfig, reverts if the pair doesn't exist
- **_checkPairParameters**: Checks whether the parameters of the PairConfig are valid. The two tokens must be added to the pool before adding the pair. It validates the two token addresses are not the same, and one of the tokens must be USD1. It also validates the fee numerators and the reserve ratio thresholds
- **_isTokenTypeValid**: Returns true when the token type is Asset or Stable
- **_checkSwapFeeNumerator**: Checks if the input of the swapping fee numerator is valid. A valid swapping fee numerator must be zero or less than the denominator. which has 6 decimal places
- **_checkReserveRatioThreshold**: Checks if the input of the reserve ratio threshold is valid. A valid threshold must be zero, or greater than or equal to the denominator, which has 18 decimals places

## TypeTokens

#### State Variables
- **_tokenType**: This mapping associates a token address with its corresponding token type. It allows you to map a specific token address to a numeric token type, represented as an uint8 value.

- **_typeTokens**: This mapping associates a token type with a set of addresses. It uses an EnumerableSetUpgradeable.AddressSet data structure to store the set of addresses associated with a particular token type. This mapping allows you to group token addresses based on their token types.

#### Modifiers

- **tokenInPool**: This modifier is used to ensure that a given token is already present in the pool. It checks the condition using the isTokenInPool function. If the token is not found in the pool, the function will revert with the TokenNotInPool error.

- **tokenNotInPool**: This modifier is used to ensure that a given token is not already present in the pool. It also checks the condition using the isTokenInPool function. If the token is found in the pool, the function will revert with the TokenAlreadyInPool error.

#### Public or External Functions

- **listTokensByIndexAndCount**: Gets token addresses of the token type, supporting pagination
- **isTokenInPool**: Returns true when token is in the pool
- **tokenLength**: Gets the token count of the token type
- **tokenByIndex**: Gets the token address for a given token type and index

#### Internal or Private Functions

- **_addToken**: Adds a token to the pool for a given token address and token type
- **_removeToken**: Removes the token from the pool

## TokenPairs

#### State Variables

- **_pairTokens**: This mapping is used to map the token address to the set of addresses, where the key and each element in the set represents a pair of tokens

- **_pairHashes**: The set of pair hashes that is used to determine whether a pair exists in the pool

#### Public or External Functions

- **listPairTokensByIndexAndCount**: Gets an array of token addresses that are paired with the specified token, supporting pagination
- **isPairInPool**: Returns true when the pair is in the pool
- **pairTokenLength**: Gets the total number of tokens that are paired with the specified token
- **pairTokenByIndex**: Gets the paired token address by the specified token and index
- **pairLength**: Gets the total number of pairs
- **getPairHash**: Sorts the two token addresses in ascending order, then returns the hash

#### Internal or Private Functions

- **_addPairByTokens**: Adds a pair to the pool by the two tokens addresses that are sorted in ascending order. Reverts if the pair already exists
- **_removePairByTokens**: Removes the pair from the pool by the two tokens addresses. Reverts if the pair does not exist
- **_checkPairExists**: Returns the hash of the pair by the two token addresses. Reverts if the pair does not exist
- **_getPairHash**: Returns the hash of the two token addresses
- **_sortTokens**: Sorts the two token addresses in ascending order

## PoolBalances

#### State Variables

- **_balance**: This mapping is used to associate an address with the balance of a token. It allows you to store and retrieve the balance of a specific token for a given address.

- **_portfolio**: This mapping is used to associate an address with the portfolio of a token. It allows you to store and retrieve the portfolio value of a specific token for a given address.

#### Internal or Private Functions

- **_setBalance**: Updates the balance state of the token
- **_setPortfolio**: Updates the portfolio state of the token
- **_receivePortfolio**: Transfers the balance of the token from the sender to the pool
- **_sendPortfolio**: Transfers the balance of the token from the pool to the portfolio manager. 
- **_getBalance**: Gets the balance state of the token
- **_getPortfolio**: Gets the portfolio state of the token
- **_checkAmountPositive**: Reverts if the amount is not greater than zero

## SwapFunctions

#### Internal or Private Functions

- **_calculateSwapResult**: Calculates the swap result by `SwapRequest`. It will return the amount to spent, the amount to receive, and the fee
- **_calculateSwapResultByAmountIn**: Calculates the swap result when the amount type is `In`.
- **_calculateSwapResultByAmountOut**: Calculates the swap result when the amount type is `Out`.
- **_validateFeeFraction**: Checks the fee fraction is valid
- **_getFeeByAmountWithFee**: Calculates the fee based on the amount including the fee
- **_getFeeByAmountWithoutFee**: Calculates the fee based on the amount excluding the fee
- **_convert**: Converts the amount of one token to another token based on the price, and allows selecting the rounding mode
- **_convertByFromPrice**: Converts the amount of source token to target token when the price is based on source token
- **_convertByToPrice**: Converts the amount of source token to target token when the price is based on target token

## XOracle

Inherits **AccessControl**.

#### State Variables

- **prices**: The mapping prices is defined with the key type address and the value type IOracle.Price.   

#### Public or External Functions

- **putPrice**: This function allows a caller with the "FEEDER_ROLE" to update the price for a specific asset. It checks if the provided timestamp is newer than the previous one and updates the price accordingly.
- **updatePrices**: This function enables a caller with the "FEEDER_ROLE" to update prices for multiple assets in a single transaction. It iterates through an array of NewPrice structs and calls the putPrice function for each entry.
- **getPrice**: A view function that retrieves the timestamp, previous timestamp, current price, and previous price for a given asset.
- **getLatestPrice**: A view function that returns only the latest price for a given asset.
- **decimals**: A pure function that returns the number of decimal places for the price data, which is hardcoded to 18.

## Why Unitas?
To understand Unitas, we can leverage USDT’s main use case.

Let us consider a scenatio where, a person A owes 1000 USD to another person B. If A and B tried to use Bitcoin for this settlement purpose, the amount of Bitcoin will keep fluctuating due to volatile nature of Bitcoin/USD rate. ETH and other crypto tokens will also be not really useful because of similar issues.
To solve for the above problem, we can issue a token which is pegged at 1 USD. This allows for an easy transaction between A and B. By bringing stability to the token price, USD pegged stablecoins solved many such accounting and financial problems. USDT enabled lending, b2b transfers, cross-border remittance and still enabling new use cases. The simplicity of USDT and it’s valued being pegged to 1 USD has led to USDT acquiring large growth and highest market share in the stablecoin market. USDC, the second largest stablecoin has similar principles and similar use cases.

Let us consider another scenario, where a person C owes another person 1000 Indian rupee. If C and D tried to use USDT for this settlement purpose, the amount of USDT will keep fluctuating due to volatile nature of USDT/INR rate. USDC/INR has the same issue. Any other USD pegged stablecoin will also be not useful for this purpose.
To solve for above problem, we are proposing INR pegged stablecoin called USD91. This will allow person C and D to easily settle their transaction without having to worry about the USDT/INR fluctuation rate. By issuing INR pegged stablecoin, USD91 we solve problems faced by local businesses and individuals. This will further enable adoption of blockchain and cypto in the India market.
Similarly we will issue other emerging market currency pegged stablecoins to enable their local economy and promote financial inclusion.

How does Unitas work?
Unitas works as a value translator for existing USD pegged stablecoins. The protocol uses oracles built by Unitas team to mint USD91 and other EMC tokens against the reserve of USDT. USD91 minters need to provide USDT, the protocol will mint equivalent in value USD91. This makes the protocol 100% reserved in USDT. This does not create any CDP and the minters are free to swap back to USDT permissionlessly.
Although the protocol is reserved 100%, volatile nature of emerging market currencies may risk the protocol of being under reserved. To mitigate againts an appreciating emerging market currency, we invite additional risk takers called Insurance Providers. Insurance providers deposit additional USDT in insurance pool to secure against an appreciating emerging market currency. The protocol rewards insurance provides by sharing the revenue.
For simplicity of development, we are launching the Unitas protocol feature with only mint and burn feature. This will enable USDT - EMC swaps on both sides. Unitas will handle the insurance pool manually for this launch and build the insurance pool smart contract in the next phase.
Other operations like monetary policies, revenue distribution and treasury management etc will be taken care manually by Unitas foundation and will be launched in phases.

Unitas protocol will allow minting of USD91, USD971, USD886, USD84 and USD1 in this phase. 

## [Unitas White Paper](https://wiki.unitas.foundation/unitas-protocol-v1/white-papers)


## Unitas Features:
## Minting

### Objectives:

- User should be able to mint USD1
- User should be able to mint USD91, USD886, USD971 and USD84 

### Features of Unitas minting process:

- It works like a swap for the users
- There will not be a CDP created
- The user’s USDT or tokens will be deposited in the Reserve pool controlled by the protocol
- Since every swap is processed by new mint, there should not be a slippage
- Once users have acquired Unitas tokens like USD1, USD91(or other EMCs like, USD971, USD886 & USD84) etc they have the complete ownership of the tokens and do not owe anything to the protocol
    - There is no expiry date for the tokens
    - Users are free to use the tokens as they desire
- There will txn fee for each mint, to be set by the protocol
    - The protocol can set the txn fee to be zero
    - However the users should be shown the txn fee value nonetheless

### Minting USD1 using USDT



- Reserve ratio = (USDT in reserve pool + USDT in Insurance pool)/(USD1 is supply)
    - If reserve ratio >130%, allow minting new USD1 or else do not allow
    - The value reserve ratio is calculated periodically and updated by itself
    
### Transaction Fee
|  |  | Mint | Burn |
| --- | --- | --- | --- |
| USDT | USD1 | 0% | 0% |
| USD1 | USD91 | 1% | 1% |
| USD1 | USD971 | 1% | 1% |
| USD1 | USD886 | 1% | 1% |
| USD1 | USD84 | 1% | 1% |
    

### User journey:

- User has USDT in their wallet
- They connect their wallet to the protocol
- They enter USD1 amount to mint
- The protocol confirms there is enough reserve in insurance pool to mint new USD1(> 130%)
    - The USDT/USD1 ratio should be above 130%
    - ie: >130%
- The protocol deducts the required USDT amount
- They choose the amount they require
- User will see relevant amount of USDT deducted from wallet balance
- User will see USD1 in their balance after the end of the process

![](https://i.imgur.com/6DRjT47.png)


### Minting USD91 and other EMCs using USD1

### User journey:

- User has USD1 in their wallet
- They connect their wallet to the protocol
- They choose the desired token from USD91, USD971, USD886 & USD84 ..
- They enter the required amount of USD1 to be converted
    - Alternatively they enter the required amount of USD91(or other EMCs like, USD971, USD886 & USD84) to be minted
- Protocol will check the oracle price and show final cost/outcome to the user
- User needs to confirm the final amount and initiate a wallet confirmation
- Once the user has approved the wallet spent the protocol will deduct the USD1 amount
- The protocol will mint USD91(or other EMCs like, USD971, USD886 & USD84) for the user
- The user will receive the USD91,USD971 amount in their wallet

![](https://i.imgur.com/BDbYYAi.png)
## Burn/Redeem

### Objectives:

- Users should be able to redeem USD91(or other EMCs like, USD971, USD886 & USD84) to USD1
- Users should be able to redeem USD1 to USDT

### Features of Unitas minting process:

- It works like a swap for the users
- The user’s USD1 or USD91(or other EMCs like, USD971, USD886 & USD84) tokens will be burnt
- Since there is no CDP created, all USD1 and USD91(or other EMCs like, USD971, USD886 & USD84) is the same for the protocol
    - The protocol will utilize oracles to get redemption amount
- Users will get USDT from reserve pool
    - If the Reserve pool does not have sufficient USDT, the protocol will utilize Insurance pool USDT
- Since every swap is processed by new mint, there should not be a slippage
- Users can redeem USDT by burning USD1 anytime
    - There is no expiry date for the tokens
    - There is no redemption window, the. protocol is active 24x7x365
- There will be txn fee for each burn, to be set by the protocol
    - The protocol can set the txn fee to be zero
    - However the users should be shown the txn fee value nonetheless

**Important questions asked by dev team:**

- Can the user redeem any amount of USD1 from the protocol?
    - Yes the redemption is permissionless and should be allowed to empty all funds if needed
    - Need to secure this in risk management
- What if we do not have enough fund in the reserve pool?
    - We withdraw funds from insurance pool
- What if we do not have enough funds in reserve pool + insurance pool combined?
    - We will need to have a clear threshold of the amount we put in other protocols to avoid bank run or delayed redemption
- Because the insurance pool is independent and manual how do we check the reserve ratio above 130% while minting new USD1
    - We use multi-sig wallet like gnosis safe
    - Minting contract will check the wallet balance before minting

### Burning USD1 to redeem USDT

### User journey:

- User has USD1 in their wallet
- User connects their wallet with the protocol
- User will enter the amount of USD1 they want to burn
- The protocol will deduct the USD1 from the wallet
    - The protocol will need user’s approval to utilize the USD1
    - Once user approves, the protocol will deduct
- There will be txn fee for each burn, to be set by the protocol
    - The protocol can set the txn fee to be zero
    - However the users should be shown the txn fee value nonetheless
    
![](https://i.imgur.com/sdcYpIP.png)


### Burning USD91(or other EMCs like, USD971, USD886 & USD84) to redeem USD1

### User journey: using USD91 as example

- User has USD91 in their wallet
- User connects their wallet with the protocol
- User will enter the amount of USD91 they want to burn
    - Alternatively users will declare the amount USD1 they want to redeem
- The protocol will deduct the USD91 from the wallet
    - The protocol will need user’s approval to utilize the USD91
    - Once user approves, the protocol will deduct
- There will be txn fee for each burn, to be set by the protocol
    - The protocol can set the txn fee to be zero
    - However the users should be shown the txn fee value nonetheless

![](https://i.imgur.com/NGFCPEU.png)

### Oracle: Phase1  

- Combine two or more oracles to get the price data we require 
    - Combine two or more oracles from CEXs or Chainlinks etc
 ![](https://i.imgur.com/kYMWQIi.png)

## Risk Management

### Risk management for minting based upon reserve ratio:

### Reserve ratio above >130%

1. allow minting of USD1
2. allow minting of USD91, USD971, USD971, USD886 & USD84 
3. allow exit of USD1 and USD91, USD971, USD886 & USD84

### Reserve ratio ≤ 130%

1. Pause USD1 minting temporarily 
2. Allow minting of USD91 and USD971, USD971, USD886 & USD84 
3. wait for reserve ratio to go above >130% to restart minting USD1 from USDT
4. allow exit of USD91,USD971, USD886 & USD84 to USD1
5. allow exit of USD1 to USDT 

### Reserve ratio ≤ 100%

1. stop all minting permanently 
2. allow exit of USD91, USD971, USD886 & USD84 to USD1
3. allow exit of USD1 to USDT

### Pause  / unpause 

- Unitas core contract: Pause and unpause token swapping.
- ERC20Token (USD1/EMC Token): Pause and unpause mint, burn and transfer.

### ERC20Toen BlackList

- addBlackList will perform over MEV protection mechanism (Flashbots)
