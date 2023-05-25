// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IHasContract.sol";

interface IHasProfileContract is IHasContract {
  /// @dev Emitted when the profile contract is updated.
  event ProfileContractUpdated(address);

  /// @dev Error of method caller must be profile contract.
  error ErrCallerMustBeProfileContract();

  /**
   * @dev Returns the profile contract.
   */
  function profileContract() external view returns (address);

  /**
   * @dev Sets the profile contract.
   *
   * Requirements:
   * - The method caller is admin.
   * - The new address is a contract.
   *
   * Emits the event `ProfileContractUpdated`.
   *
   */
  function setProfileContract(address) external;
}
