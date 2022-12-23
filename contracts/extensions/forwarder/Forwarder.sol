// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./ForwarderLogic.sol";
import "./ForwarderStorage.sol";

contract Forwarder is ForwarderLogic, ForwarderStorage, AccessControl {
  /// @dev Moderator of the forwarder role hash
  bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");

  /**
   * @dev Initializes the forwarder with an initial target specified by `__target`.
   */
  constructor(address __target, address __admin) payable {
    _changeTargetTo(__target);
    _changeForwarderAdmin(__admin);
    _setupRole(DEFAULT_ADMIN_ROLE, __admin);
  }

  modifier onlyModerator() {
    require(hasRole(MODERATOR_ROLE, msg.sender), "Forwarder: unauthorized call");
    _;
  }

  modifier adminExecutesOrModeratorForwards() {
    if (msg.sender == _getAdmin()) {
      _;
    } else {
      require(hasRole(MODERATOR_ROLE, msg.sender), "Forwarder: unauthorized call");
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
   * @dev Receives ether transfer from all addresses.
   */
  receive() external payable override {}

  /**
   * @dev Returns the current target.
   *
   * NOTE: Only the admin can call this function. See {ForwarderStorage-_getTarget}.
   *
   * TIP: To get this value clients can read directly from the storage slot shown below using the
   * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
   * `0xef66ca965b5cc064c3b2723445ac3a82b48db478c3cd5ef4620f7f96f1b1a19a`
   */
  function target() external adminExecutesOrModeratorForwards returns (address target_) {
    target_ = _target();
  }

  /**
   * @dev Changes the admin of the forwarder.
   *
   * Emits an {AdminChanged} event.
   *
   * NOTE: Only the admin can call this function. See {ForwarderStorage-_changeForwarderAdmin}.
   */
  function changeForwarderAdmin(address newAdmin) external virtual adminExecutesOrModeratorForwards {
    _changeForwarderAdmin(newAdmin);
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
   * - Only `MODERATOR_ROLE` users can call this method.
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

  /**
   * @dev Returns the current admin.
   */
  function _admin() internal view virtual returns (address) {
    return _getAdmin();
  }
}
