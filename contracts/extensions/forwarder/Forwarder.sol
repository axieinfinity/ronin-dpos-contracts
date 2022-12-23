// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ForwarderLogic.sol";
import "./ForwarderRole.sol";

contract Forwarder is ForwarderLogic, ForwarderRole {
  /**
   * @dev Initializes the forwarder with an initial target specified by `__target`.
   */
  constructor(address __target, address __admin) payable {
    _changeTargetTo(__target);
    _changeAdminTo(__admin);
  }

  modifier onlyModerator() {
    require(_isModerator(msg.sender), "Forwarder: unauthorized call");
    _;
  }

  modifier adminExecutesOrModeratorForwards() {
    if (_isAdmin(msg.sender)) {
      _;
    } else {
      require(_isModerator(msg.sender), "Forwarder: unauthorized call");
      _fallback();
    }
  }

  /**
   * @dev Forwards the call to the target (the `msg.value` is sent along in the call).
   *
   * Requirements:
   * - Only moderator can invoke fallback method.
   */
  fallback() external payable override onlyModerator {
    _fallback();
  }

  /**
   * @dev Receives RON transfer from all addresses.
   */
  receive() external payable override {}

  /**
   * @dev Returns the current admin.
   *
   * NOTE: Only the admin can call this function. See {ForwarderStorage-_getAdmin}.
   *
   * TIP: To get this value clients can read directly from the storage slot shown below using the
   * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
   * `0xa8c82e6b38a127695961bbff56774712a221ab251224d4167eab01e23fcee6ca`
   */
  function admin() external adminExecutesOrModeratorForwards returns (address admin_) {
    admin_ = _getAdmin();
  }

  /**
   * @dev Changes the admin of the forwarder.
   *
   * Emits an {AdminChanged} event.
   *
   * NOTE: Only the admin can call this function. See {ForwarderStorage-_changeAdminTo}.
   */
  function changeAdminTo(address newAdmin) external virtual adminExecutesOrModeratorForwards {
    _changeAdminTo(newAdmin);
  }

  /**
   * @dev Returns the current target.
   *
   * NOTE: Only the admin can call this function. See {ForwarderStorage-_getTarget}.
   *
   * TIP: To get this value clients can read directly from the storage slot shown below using the
   * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
   * `0xcbec2a70e8f0a52aeb8f96e02517dc497e58d9a6fa86ab4056563f1e6baf3d3e`
   */
  function moderator() external adminExecutesOrModeratorForwards returns (address moderator_) {
    moderator_ = _getModerator();
  }

  /**
   * @dev Changes the moderator of the forwarder.
   *
   * Emits an {ModeratorChanged} event.
   *
   * NOTE: Only the moderator can call this function. See {ForwarderStorage-_changeModeratorTo}.
   */
  function changeModeratorTo(address newModerator) external virtual adminExecutesOrModeratorForwards {
    _changeModeratorTo(newModerator);
  }

  /**
   * @dev Returns the current target.
   *
   * NOTE: Only the moderator can call this function. See {ForwarderStorage-_getTarget}.
   *
   * TIP: To get this value clients can read directly from the storage slot shown below using the
   * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
   * `0x58221d865d4bfcbfe437720ee0c958ac3269c4e9c775f643bf474ed980d61168`
   */
  function target() external adminExecutesOrModeratorForwards returns (address target_) {
    target_ = _target();
  }

  /**
   * @dev Changes the target of the forwarder.
   *
   * Emits an {TargetChanged} event.
   *
   * NOTE: Only the admin can call this function. See {ForwarderStorage-_changeTargetTo}.
   */
  function changeTargetTo(address newTarget) external virtual adminExecutesOrModeratorForwards {
    _changeTargetTo(newTarget);
  }

  /**
   * @dev Forwards the encoded call specified by `_data` to the target. The forwarder attachs `_val` value
   * from the forwarder contract and sends along with the call.
   *
   * Requirements:
   * - Only moderator can call this method.
   */
  function functionCall(bytes memory _data, uint256 _val) external payable onlyModerator {
    _functionCall(_data, _val);
  }

  /**
   * @dev Calls a function from the current forwarder to the target as specified by `_data`, which should be an encoded
   * function call, with the value `_val`.
   */
  function _functionCall(bytes memory _data, uint256 _val) internal {
    require(_val <= address(this).balance, "Forwarder: invalid forwarding value");
    _call(_target(), _data, _val);
  }

  /**
   * @dev Returns the current target address.
   */
  function _target() internal view virtual override returns (address target_) {
    return _getTarget();
  }
}
