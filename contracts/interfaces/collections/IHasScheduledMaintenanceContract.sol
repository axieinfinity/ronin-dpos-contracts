// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IHasScheduledMaintenanceContract {
  /// @dev Emitted when the scheduled maintenance contract is updated.
  event ScheduledMaintenanceContractUpdated(address);

  /**
   * @dev Returns the scheduled maintenance contract.
   */
  function scheduledMaintenanceContract() external view returns (address);

  /**
   * @dev Sets the scheduled maintenance contract.
   *
   * Requirements:
   * - The method caller is admin.
   * - The new address is a contract.
   *
   * Emits the event `ScheduledMaintenanceContractUpdated`.
   *
   */
  function setScheduledMaintenanceContract(address) external;
}
