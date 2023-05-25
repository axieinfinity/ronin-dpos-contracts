// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ErrProxyCallFailed } from "./Errors.sol";

library ErrorHandler {
  function handleRevert(
    bool status,
    bytes4 callSig,
    bytes memory returnOrRevertData
  ) internal pure {
    bytes4 msgSig = msg.sig;
    assembly {
      if iszero(status) {
        let revertLength := mload(returnOrRevertData)
        if iszero(iszero(revertLength)) {
          // Start of revert data bytes. The 0x20 offset is always the same.
          revert(add(returnOrRevertData, 0x20), revertLength)
        }

        /// @dev equivalent to revert ErrProxyCallFailed(bytes4,bytes4)
        let freeMemPtr := mload(0x40)
        mstore(freeMemPtr, 0x8e3eda2b)
        mstore(add(freeMemPtr, 0x20), msgSig)
        mstore(add(freeMemPtr, 0x40), callSig)
        revert(add(freeMemPtr, 0x1c), 0x44)
      }
    }
  }
}
