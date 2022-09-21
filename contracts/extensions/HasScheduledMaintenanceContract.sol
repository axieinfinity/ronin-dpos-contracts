// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./HasProxyAdmin.sol";
import "../interfaces/collections/IHasScheduledMaintenanceContract.sol";
import "../interfaces/IScheduledMaintenance.sol";

contract HasScheduledMaintenanceContract is IHasScheduledMaintenanceContract, HasProxyAdmin {
  IScheduledMaintenance internal _scheduledMaintenanceContract;

  modifier onlyScheduledMaintenanceContract() {
    require(
      scheduledMaintenanceContract() == msg.sender,
      "HasScheduledMaintenanceContract: method caller must be scheduled maintenance contract"
    );
    _;
  }

  /**
   * @inheritdoc IHasScheduledMaintenanceContract
   */
  function scheduledMaintenanceContract() public view override returns (address) {
    return address(_scheduledMaintenanceContract);
  }

  /**
   * @inheritdoc IHasScheduledMaintenanceContract
   */
  function setScheduledMaintenanceContract(address _addr) external override onlyAdmin {
    _setScheduledMaintenanceContract(_addr);
  }

  /**
   * @dev Sets the scheduled maintenance contract.
   *
   * Requirements:
   * - The new address is a contract.
   *
   * Emits the event `ScheduledMaintenanceContractUpdated`.
   *
   */
  function _setScheduledMaintenanceContract(address _addr) internal {
    _scheduledMaintenanceContract = IScheduledMaintenance(_addr);
    emit ScheduledMaintenanceContractUpdated(_addr);
  }
}
