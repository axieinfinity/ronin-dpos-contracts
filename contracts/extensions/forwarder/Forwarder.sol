// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ForwarderLogic.sol";
import "./ForwarderStorage.sol";

contract Forwarder is ForwarderLogic, ForwarderStorage {
  /**
   * @dev Initializes the forwarder with an initial target specified by `__target`.
   */
  constructor(address __target, address __admin) payable {
    _changeTargetTo(__target);
    _changeAdmin(__admin);
  }

  /**
   * @dev Returns the current target address.
   */
  function _target() internal view virtual override returns (address target_) {
    return ForwarderStorage._getTarget();
  }

  /**
   * @dev Modifier used internally that will forward the call to the target unless the sender is the admin.
   */
  modifier ifAdmin() {
    if (msg.sender == _getAdmin()) {
      _;
    } else {
      _fallback();
    }
  }

  /**
   * @dev Returns the current admin.
   *
   * NOTE: Only the admin can call this function. See {ForwarderStorage-_getAdmin}.
   *
   * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using the
   * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
   * `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103`
   */
  function admin() external ifAdmin returns (address admin_) {
    admin_ = _getAdmin();
  }

  /**
   * @dev Returns the current target.
   *
   * NOTE: Only the admin can call this function. See {ForwarderStorage-_getTarget}.
   *
   * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using the
   * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
   * `0x99eb7666c084b9136a94e6a829f687abc476d287db070ef792cda8b663eb029e`
   */
  function target() external ifAdmin returns (address target_) {
    target_ = _target();
  }

  /**
   * @dev Changes the admin of the forwarder.
   *
   * Emits an {AdminChanged} event.
   *
   * NOTE: Only the admin can call this function. See {ForwarderStorage-_changeAdmin}.
   */
  function changeAdmin(address newAdmin) external virtual ifAdmin {
    _changeAdmin(newAdmin);
  }

  /**
   * @dev Changes the target of the forwarder.
   *
   * Emits an {TargetChanged} event.
   *
   * NOTE: Only the admin can call this function. See {ForwarderStorage-_changeTargetTo}.
   */
  function changeTargetTo(address newTarget) external virtual ifAdmin {
    _changeTargetTo(newTarget);
  }

  /**
   * @dev See {Forwarder-_functionCall}.
   *
   * The originated value from the transaction is included in the call, and is forwarded to the target.
   *
   * Requirements:
   * - Only the admin can call this function.
   *
   * Note: The forwarder admin is not allowed to interact with the target through the fallback function to avoid
   * triggering some unexpected logic. This method is used to allow the administrator to explicitly call the target,
   * please consider reviewing the encoded data `_data` and the method which is called before using this.
   *
   */
  function functionCall(bytes memory _data, uint256 _val) external payable virtual ifAdmin {
    _functionCall(_data, _val);
  }

  /**
   * @dev Calls a function from the current forwarder to the target as specified by `_data`, which should be an encoded
   * function call, with the value `_val`.
   */
  function _functionCall(bytes memory _data, uint256 _val) internal {
    require(_val <= address(this).balance, "Forwarder: invalid forwarding value");
    address _addr = _target();
    assembly {
      // Call the implementation
      // out and outsize are 0 because we don't know the size yet.
      let _result := call(gas(), _addr, _val, add(_data, 32), mload(_data), 0, 0)

      returndatacopy(0, 0, returndatasize())

      switch _result
      case 0 {
        revert(0, returndatasize())
      }
      default {
        return(0, returndatasize())
      }
    }
  }

  /**
   * @dev Returns the current admin.
   */
  function _admin() internal view virtual returns (address) {
    return _getAdmin();
  }
}
