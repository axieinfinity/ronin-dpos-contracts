// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { RONTransferHelper } from "../extensions/RONTransferHelper.sol";
import { ErrZeroAddress, ErrOnlySelfCall, ErrZeroCodeContract, ErrNonpayableAddress } from "./CommonErrors.sol";

abstract contract IdentityGuard is RONTransferHelper {
  /**
   * @dev Modifier to restrict functions to only be called by this contract.
   * @dev Reverts if the caller is not this contract.
   */
  modifier onlySelfCall() virtual {
    _requireSelfCall();
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
   * @dev Checks if an address non-payable and reverts if it is.
   * @param addr The address to check.
   */
  function _requirePayableAddress(address addr) internal {
    if (!_unsafeSendRON(payable(addr), 0, 0)) {
      revert ErrNonpayableAddress(addr);
    }
  }

  /**
   * @dev Checks if an address is zero and reverts if it is.
   * @param addr The address to check.
   */
  function _requireNonZeroAddress(address addr) internal pure {
    if (addr == address(0)) revert ErrZeroAddress(msg.sig);
  }
}