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
      uint _size = _res.length;
      require(_size >= 4, "Forwarder: target reverts silently");
      assembly {
        _res := add(_res, 0x20)
        revert(_res, _size)
      }
    }
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
