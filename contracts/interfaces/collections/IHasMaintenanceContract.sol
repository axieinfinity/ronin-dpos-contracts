// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IHasContract.sol";

interface IHasMaintenanceContract is IHasContract {
  /// @dev Emitted when the maintenance contract is updated.
  event MaintenanceContractUpdated(address);

  /// @dev Error of method caller must be maintenance contract.
  error ErrCallerMustBeMaintenanceContract();

  /**
   * @dev Returns the maintenance contract.
   */
  function maintenanceContract() external view returns (address);

  /**
   * @dev Sets the maintenance contract.
   *
   * Requirements:
   * - The method caller is admin.
   * - The new address is a contract.
   *
   * Emits the event `MaintenanceContractUpdated`.
   *
   */
  function setMaintenanceContract(address) external;
}
