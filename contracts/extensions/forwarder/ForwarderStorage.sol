// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/StorageSlot.sol";

abstract contract ForwarderStorage {
  /**
   * @dev Storage slot with the address of the current target.
   * This is the keccak-256 hash of "eip1967.forwarder.target" subtracted by 1, and is
   * validated in the constructor.
   */
  bytes32 internal constant _TARGET_SLOT = 0xef66ca965b5cc064c3b2723445ac3a82b48db478c3cd5ef4620f7f96f1b1a19a;

  /**
   * @dev Emitted when the target is changed.
   */
  event TargetChanged(address indexed target);

  /**
   * @dev Returns the current target address.
   */
  function _getTarget() internal view returns (address) {
    return StorageSlot.getAddressSlot(_TARGET_SLOT).value;
  }

  /**
   * @dev Stores a new address in the EIP1967 target slot.
   */
  function _setTarget(address newTarget) private {
    require(Address.isContract(newTarget), "ForwarderStorage: new target is not a contract");
    StorageSlot.getAddressSlot(_TARGET_SLOT).value = newTarget;
  }

  /**
   * @dev Perform target upgrade
   *
   * Emits an {TargetChanged} event.
   */
  function _changeTargetTo(address newTarget) internal {
    _setTarget(newTarget);
    emit TargetChanged(newTarget);
  }

  /**
   * @dev Storage slot with the admin of the contract.
   * This is the keccak-256 hash of "eip1967.forwarder.admin" subtracted by 1, and is
   * validated in the constructor.
   */
  bytes32 internal constant _ADMIN_SLOT = 0x79a79760a074c8fb895d1b610f58e9e8356cbfa4196cb8f560d5a1205dae8d07;

  /**
   * @dev Emitted when the admin account has changed.
   */
  event AdminChanged(address previousAdmin, address newAdmin);

  /**
   * @dev Returns the current admin.
   */
  function _getAdmin() internal view returns (address) {
    return StorageSlot.getAddressSlot(_ADMIN_SLOT).value;
  }

  /**
   * @dev Stores a new address in the EIP1967 admin slot.
   */
  function _setAdmin(address newAdmin) private {
    require(newAdmin != address(0), "ForwarderStorage: new admin is the zero address");
    StorageSlot.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
  }

  /**
   * @dev Changes the admin of the forwarder.
   *
   * Emits an {AdminChanged} event.
   */
  function _changeForwarderAdmin(address newAdmin) internal {
    emit AdminChanged(_getAdmin(), newAdmin);
    _setAdmin(newAdmin);
  }
}
