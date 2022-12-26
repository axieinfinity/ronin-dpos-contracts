// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/StorageSlot.sol";

abstract contract ForwarderRole {
  /// @dev Storage slot with the address of the current admin. This is the keccak-256 hash of "ronin.forwarder.admin" subtracted by 1.
  bytes32 internal constant _ADMIN_SLOT = 0xa8c82e6b38a127695961bbff56774712a221ab251224d4167eab01e23fcee6ca;
  /// @dev Storage slot with the address of the current target. This is the keccak-256 hash of "ronin.forwarder.target" subtracted by 1.
  bytes32 internal constant _TARGET_SLOT = 0x58221d865d4bfcbfe437720ee0c958ac3269c4e9c775f643bf474ed980d61168;
  /// @dev Storage slot with the address of the current target. This is the keccak-256 hash of "ronin.forwarder.moderator" subtracted by 1.
  bytes32 internal constant _MODERATOR_SLOT = 0xcbec2a70e8f0a52aeb8f96e02517dc497e58d9a6fa86ab4056563f1e6baf3d3e;

  /// @dev Emitted when the target is changed.
  event AdminChanged(address indexed admin);
  /// @dev Emitted when the target is changed.
  event TargetChanged(address indexed target);
  /// @dev Emitted when the target is changed.
  event ModeratorChanged(address indexed target);

  /**
   * @dev Returns the current admin address.
   */
  function _getAdmin() internal view returns (address) {
    return StorageSlot.getAddressSlot(_ADMIN_SLOT).value;
  }

  /**
   * @dev Stores a new address in the admin slot.
   */
  function _setAdmin(address newAdmin) private {
    StorageSlot.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
  }

  function _isAdmin(address _addr) internal view returns (bool) {
    return _addr == _getAdmin();
  }

  /**
   * @dev Perform admin upgrade
   *
   * Emits an {AdminChanged} event.
   */
  function _changeAdminTo(address newAdmin) internal {
    _setAdmin(newAdmin);
    emit AdminChanged(newAdmin);
  }

  /**
   * @dev Returns the current target address.
   */
  function _getTarget() internal view returns (address) {
    return StorageSlot.getAddressSlot(_TARGET_SLOT).value;
  }

  /**
   * @dev Stores a new address in the target slot.
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
   * @dev Returns the current moderator address.
   */
  function _getModerator() internal view returns (address) {
    return StorageSlot.getAddressSlot(_MODERATOR_SLOT).value;
  }

  /**
   * @dev Stores a new address in the EIP1967 moderator slot.
   */
  function _setModerator(address newModerator) private {
    StorageSlot.getAddressSlot(_MODERATOR_SLOT).value = newModerator;
  }

  /**
   * @dev Perform moderator upgrade
   *
   * Emits an {ModeratorChanged} event.
   */
  function _changeModeratorTo(address newModerator) internal {
    _setModerator(newModerator);
    emit ModeratorChanged(newModerator);
  }

  function _isModerator(address _addr) internal view returns (bool) {
    return _addr == _getModerator();
  }
}
