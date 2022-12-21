// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract ForwarderLogic {
  /**
   * @dev Forwards the current call to `target`.
   *
   * This function does not return to its internal call site, it will return directly to the external caller.
   */
  function _call(address target) internal {
    uint value = msg.value;
    assembly {
      // Copy msg.data. We take full control of memory in this inline assembly
      // block because it will not return to Solidity code. We overwrite the
      // Solidity scratch pad at memory position 0.
      calldatacopy(0, 0, calldatasize())

      // Call the implementation
      // out and outsize are 0 because we don't know the size yet.
      let result := call(gas(), target, value, 0, calldatasize(), 0, 0)

      // Copy the returned data.
      returndatacopy(0, 0, returndatasize())

      switch result
      // delegatecall returns 0 on error.
      case 0 {
        revert(0, returndatasize())
      }
      default {
        return(0, returndatasize())
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
  function _fallback() internal virtual {
    _call(_target());
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
