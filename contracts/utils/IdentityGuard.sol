// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AddressArrayUtils } from "../libraries/AddressArrayUtils.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { ErrZeroAddress, ErrOnlySelfCall, ErrZeroCodeContract, ErrUnsupportedInterface } from "./CommonErrors.sol";

abstract contract IdentityGuard {
  using AddressArrayUtils for address[];

  /**
   * @dev Modifier to restrict functions to only be called by this contract.
   * @dev Reverts if the caller is not this contract.
   */
  modifier onlySelfCall() virtual {
    _requireSelfCall();
    _;
  }

  /**
   * @dev Modifier to ensure that the elements in the `arr` array are non-duplicates.
   * It calls the internal `_checkDuplicate` function to perform the duplicate check.
   *
   * Requirements:
   * - The elements in the `arr` array must not contain any duplicates.
   */
  modifier nonDuplicate(address[] memory arr) virtual {
    _requireNonDuplicate(arr);
    _;
  }

  /**
   * @dev Internal method to check the method caller.
   * @dev Reverts if the method caller is not this contract.
   */
  function _requireSelfCall() internal view virtual {
    if (msg.sender != address(this)) revert ErrOnlySelfCall(msg.sig);
  }

  /**
   * @dev Internal function to check if a contract address has code.
   * @param addr The address of the contract to check.
   * @dev Throws an error if the contract address has no code.
   */
  function _requireHasCode(address addr) internal view {
    if (addr.code.length == 0) revert ErrZeroCodeContract(addr);
  }

  /**
   * @dev Checks if an address is zero and reverts if it is.
   * @param addr The address to check.
   */
  function _requireNonZeroAddress(address addr) internal pure {
    if (addr == address(0)) revert ErrZeroAddress(msg.sig);
  }

  /**
   * @dev Check if arr is empty and revert if it is.
   * Checks if an array contains any duplicate addresses and reverts if duplicates are found.
   * @param arr The array of addresses to check.
   */
  function _requireNonDuplicate(address[] memory arr) internal pure {
    if (arr.hasDuplicate()) revert AddressArrayUtils.ErrDuplicated(msg.sig);
  }

  /**
   * @dev Internal function to require that the specified contract supports the given interface.
   * @param contractAddr The address of the contract to check for interface support.
   * @param interfaceId The interface ID to check for support.
   * @dev If the contract does not support the interface, a revert with the corresponding error message is triggered.
   */
  function _requireSupportsInterface(address contractAddr, bytes4 interfaceId) internal view {
    if (!IERC165(contractAddr).supportsInterface(interfaceId)) {
      revert ErrUnsupportedInterface(interfaceId, contractAddr);
    }
  }
}
