// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./HasProxyAdmin.sol";
import "../interfaces/collections/IHasMaintenanceContract.sol";
import "../interfaces/IMaintenance.sol";

contract HasMaintenanceContract is IHasMaintenanceContract, HasProxyAdmin {
  IMaintenance internal _maintenanceContract;

  modifier onlyMaintenanceContract() {
    require(
      maintenanceContract() == msg.sender,
      "HasMaintenanceContract: method caller must be scheduled maintenance contract"
    );
    _;
  }

  /**
   * @inheritdoc IHasMaintenanceContract
   */
  function maintenanceContract() public view override returns (address) {
    return address(_maintenanceContract);
  }

  /**
   * @inheritdoc IHasMaintenanceContract
   */
  function setMaintenanceContract(address _addr) external override onlyAdmin {
    _setMaintenanceContract(_addr);
  }

  /**
   * @dev Sets the scheduled maintenance contract.
   *
   * Requirements:
   * - The new address is a contract.
   *
   * Emits the event `MaintenanceContractUpdated`.
   *
   */
  function _setMaintenanceContract(address _addr) internal {
    _maintenanceContract = IMaintenance(_addr);
    emit MaintenanceContractUpdated(_addr);
  }
}
