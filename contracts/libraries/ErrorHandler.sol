// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ErrProxyCallFailed } from "../utils/CommonErrors.sol";

library ErrorHandler {
  /// @notice handle low level call revert if call failed,
  /// If extcall return empty bytes, reverts with custom error.
  /// @param status Status of external call
  /// @param callSig function signature of the calldata
  /// @param returnOrRevertData bytes result from external call
  function handleRevert(bool status, bytes4 callSig, bytes memory returnOrRevertData) internal pure {
    // Get the function signature of current context
    bytes4 msgSig = msg.sig;
    assembly {
      if iszero(status) {
        // Load the length of bytes array
        let revertLength := mload(returnOrRevertData)
        // Check if length != 0 => revert following reason from external call
        if iszero(iszero(revertLength)) {
          // Start of revert data bytes. The 0x20 offset is always the same.
          revert(add(returnOrRevertData, 0x20), revertLength)
        }

        // Load free memory pointer
        let ptr := mload(0x40)
        // Store 4 bytes the function selector of ErrProxyCallFailed(msg.sig, callSig)
        // Equivalent to revert ErrProxyCallFailed(bytes4,bytes4)
        mstore(ptr, 0x8e3eda2b)
        // Store 4 bytes of msgSig parameter in the next slot
        mstore(add(ptr, 0x20), msgSig)
        // Store 4 bytes of callSig parameter in the next slot
        mstore(add(ptr, 0x40), callSig)
        // Revert 68 bytes of error starting from 0x1c
        revert(add(ptr, 0x1c), 0x44)
      }
    }
  }
}
