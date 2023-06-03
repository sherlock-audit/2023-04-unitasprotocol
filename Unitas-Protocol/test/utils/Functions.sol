// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

/**
 * @notice Gets the error message by `errorCode`
 * @dev Differing from `_revert`, use a simpler approach to ensure consistent results
 */
function _errorMessage(uint256 errorCode) pure returns (bytes memory) {
    return bytes(string.concat("Unitas: ", StringsUpgradeable.toString(errorCode)));
}
