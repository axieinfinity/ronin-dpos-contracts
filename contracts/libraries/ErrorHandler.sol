// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ErrProxyCallFailed } from "./CommonErrors.sol";

library ErrorHandler {
  /// @notice handle low level call revert if call failed,
  /// if extcall return empty bytes, revert with custom error
  /// @param status Status of external call
  /// @param callSig function signature of the calldata
  /// @param returnOrRevertData bytes result from external call
  function handleRevert(
    bool status,
    bytes4 callSig,
    bytes memory returnOrRevertData
  ) internal pure {
    /// get the function signature of current context
    bytes4 msgSig = msg.sig;
    assembly {
      if iszero(status) {
        /// load the length of bytes array
        let revertLength := mload(returnOrRevertData)
        /// check if length != 0 => revert following reason from external call
        if iszero(iszero(revertLength)) {
          // Start of revert data bytes. The 0x20 offset is always the same.
          revert(add(returnOrRevertData, 0x20), revertLength)
        }

        /// load free memory pointer
        let freeMemPtr := mload(0x40)
        /// store 4 bytes the function selector of ErrProxyCallFailed(msg.sig, callSig)
        /// @dev equivalent to revert ErrProxyCallFailed(bytes4,bytes4)
        mstore(freeMemPtr, 0x8e3eda2b)
        /// store 4 bytes of msgSig parameter in the next slot
        mstore(add(freeMemPtr, 0x20), msgSig)
        /// store 4 bytes of callSig parameter in the next slot
        mstore(add(freeMemPtr, 0x40), callSig)
        // revert 68 bytes of error starting from 0x1c
        revert(add(freeMemPtr, 0x1c), 0x44)
      }
    }
  }
}
