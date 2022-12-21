// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract ForwarderLogic {
  /**
   * @dev Forwards the current call to `target`.
   *
   * This function does not return to its internal call site, it will return directly to the external caller.
   */
  function _call(
    address __target,
    bytes memory __data,
    uint256 __value
  ) internal {
    (bool _success, bytes memory _res) = __target.call{ value: __value }(__data);

    if (!_success) {
      _handleRevertMsg(_res);
    }
  }

  /**
   * @dev Handle revert message from internal call to human-readable.
   */
  function _handleRevertMsg(bytes memory _returnData) internal pure {
    // If the _res length is less than 68, then the transaction failed silently (without a revert message)
    if (_returnData.length < 68) {
      revert("Forwarder: reverted silently");
    }

    assembly {
      // Slice the sighash.
      _returnData := add(_returnData, 0x04)
    }

    // All that remains is the revert string
    revert(abi.decode(_returnData, (string)));
  }

  /**
   * @dev This is a virtual function that should be overridden so it returns the address to which the fallback function
   * and {_fallback} should forward.
   */
  function _target() internal view virtual returns (address);

  /**
   * @dev Forwards the current call to the address returned by `_target()`.
   *
   * This function does not return to its internal call site, it will return directly to the external caller.
   */
  function _fallback() internal {
    _call(_target(), msg.data, msg.value);
  }

  /**
   * @dev Fallback function that calls to the address returned by `_target()`. Will run if no other function in the
   * contract matches the call data.
   */
  fallback() external payable virtual {
    _fallback();
  }

  /**
   * @dev Fallback function that calls to the address returned by `_target()`. Will run if call data is empty.
   */
  receive() external payable virtual {
    _fallback();
  }
}
