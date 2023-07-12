// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Safe NATIVE and ERC20 transfer library that gracefully handles missing return values.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// @dev Caution! This library won't check that a token has code, responsibility is delegated to the caller.
library LibSafeTransfer {
  /**
   * @dev Error indicating that the approval operation has failed.
   */
  error ErrApproveFailed();

  /**
   * @dev Error indicating that the transfer operation has failed.
   */
  error ErrTransferFailed();

  /**
   * @dev Error indicating that the transferFrom operation has failed.
   */
  error ErrTransferFromFailed();

  /**
   * @dev Error indicating that the native token transfer operation has failed.
   */
  error ErrNativeTransferFailed();

  /// @dev Suggested gas stipend for contract receiving NATIVE
  /// that disallows any storage writes.
  uint256 internal constant GAS_STIPEND_NO_STORAGE_WRITES = 2300;

  /// @dev Suggested gas stipend for contract receiving NATIVE to perform a few
  /// storage reads and writes, but low enough to prevent griefing.
  /// Multiply by a small constant (e.g. 2), if needed.
  uint256 internal constant GAS_STIPEND_NO_GRIEF = 100_000;

  /*//////////////////////////////////////////////////////////////
                             NATIVE OPERATIONS
    //////////////////////////////////////////////////////////////*/

  function safeNativeTransfer(address to, uint256 amount) internal {
    bytes4 nativeTransferFailed = ErrNativeTransferFailed.selector;
    /// @solidity memory-safe-assembly
    assembly {
      // Transfer the NATIVE and check if it succeeded or not.
      if iszero(call(gas(), to, amount, 0, 0, 0, 0)) {
        // Store the function selector of `ErrNativeTransferFailed()`.
        mstore(0x00, nativeTransferFailed)
        // Revert with (offset, size).
        revert(0x1c, 0x04)
      }
    }
  }

  /// @dev Force sends `amount` (in wei) NATIVE to `to`, with a `gasStipend`.
  /// The `gasStipend` can be set to a low enough value to prevent
  /// storage writes or gas griefing.
  ///
  /// If sending via the normal procedure fails, force sends the NATIVE by
  /// creating a temporary contract which uses `SELFDESTRUCT` to force send the NATIVE.
  ///
  /// Reverts if the current contract has insufficient balance.
  function forceSafeNativeTransfer(address to, uint256 amount, uint256 gasStipend) internal {
    bytes4 nativeTransferFailed = ErrNativeTransferFailed.selector;
    /// @solidity memory-safe-assembly
    assembly {
      // If insufficient balance, revert.
      if lt(selfbalance(), amount) {
        // Store the function selector of `ErrNativeTransferFailed()`.
        mstore(0x00, nativeTransferFailed)
        // Revert with (offset, size).
        revert(0x1c, 0x04)
      }
      // Transfer the NATIVE and check if it succeeded or not.
      if iszero(call(gasStipend, to, amount, 0, 0, 0, 0)) {
        mstore(0x00, to) // Store the address in scratch space.
        mstore8(0x0b, 0x73) // Opcode `PUSH20`.
        mstore8(0x20, 0xff) // Opcode `SELFDESTRUCT`.
        // We can directly use `SELFDESTRUCT` in the contract creation.
        // Compatible with `SENDALL`: https://eips.ethereum.org/EIPS/eip-4758
        if iszero(create(amount, 0x0b, 0x16)) {
          // For better gas estimation.
          if iszero(gt(gas(), 1000000)) {
            revert(0, 0)
          }
        }
      }
    }
  }

  /// @dev Force sends `amount` (in wei) NATIVE to `to`, with a gas stipend
  /// equal to `GAS_STIPEND_NO_GRIEF`. This gas stipend is a reasonable default
  /// for 99% of cases and can be overriden with the three-argument version of this
  /// function if necessary.
  ///
  /// If sending via the normal procedure fails, force sends the NATIVE by
  /// creating a temporary contract which uses `SELFDESTRUCT` to force send the NATIVE.
  ///
  /// Reverts if the current contract has insufficient balance.
  function forceSafeNativeTransfer(address to, uint256 amount) internal {
    bytes4 nativeTransferFailed = ErrNativeTransferFailed.selector;
    // Manually inlined because the compiler doesn't inline functions with branches.
    /// @solidity memory-safe-assembly
    assembly {
      // If insufficient balance, revert.
      if lt(selfbalance(), amount) {
        // Store the function selector of `ErrNativeTransferFailed()`.
        mstore(0x00, nativeTransferFailed)
        // Revert with (offset, size).
        revert(0x1c, 0x04)
      }
      // Transfer the NATIVE and check if it succeeded or not.
      if iszero(call(GAS_STIPEND_NO_GRIEF, to, amount, 0, 0, 0, 0)) {
        mstore(0x00, to) // Store the address in scratch space.
        mstore8(0x0b, 0x73) // Opcode `PUSH20`.
        mstore8(0x20, 0xff) // Opcode `SELFDESTRUCT`.
        // We can directly use `SELFDESTRUCT` in the contract creation.
        // Compatible with `SENDALL`: https://eips.ethereum.org/EIPS/eip-4758
        if iszero(create(amount, 0x0b, 0x16)) {
          // For better gas estimation.
          if iszero(gt(gas(), 1000000)) {
            revert(0, 0)
          }
        }
      }
    }
  }

  /// @dev Sends `amount` (in wei) NATIVE to `to`, with a `gasStipend`.
  /// The `gasStipend` can be set to a low enough value to prevent
  /// storage writes or gas griefing.
  ///
  /// Simply use `gasleft()` for `gasStipend` if you don't need a gas stipend.
  ///
  /// Note: Does NOT revert upon failure.
  /// Returns whether the transfer of NATIVE is successful instead.
  function trySafeNativeTransfer(address to, uint256 amount, uint256 gasStipend) internal returns (bool success) {
    /// @solidity memory-safe-assembly
    assembly {
      // Transfer the NATIVE and check if it succeeded or not.
      success := call(gasStipend, to, amount, 0, 0, 0, 0)
    }
  }

  /*//////////////////////////////////////////////////////////////
                            ERC20 OPERATIONS
    //////////////////////////////////////////////////////////////*/

  function safeERC20TransferFrom(address token, address from, address to, uint256 amount) internal {
    bytes4 transferFromFailed = ErrTransferFromFailed.selector;
    /// @solidity memory-safe-assembly
    assembly {
      let m := mload(0x40) // Cache the free memory pointer.

      mstore(0x60, amount) // Store the `amount` argument.
      mstore(0x40, to) // Store the `to` argument.
      mstore(0x2c, shl(96, from)) // Store the `from` argument.
      // Store the function selector of `transferFrom(address,address,uint256)`.
      mstore(0x0c, 0x23b872dd000000000000000000000000)

      if iszero(
        and(
          // The arguments of `and` are evaluated from right to left.
          // Set success to whether the call reverted, if not we check it either
          // returned exactly 1 (can't just be non-zero data), or had no return data.
          or(eq(mload(0x00), 1), iszero(returndatasize())),
          call(gas(), token, 0, 0x1c, 0x64, 0x00, 0x20)
        )
      ) {
        // Store the function selector of `ErrTransferFromFailed()`.
        mstore(0x00, transferFromFailed)
        // Revert with (offset, size).
        revert(0x1c, 0x04)
      }

      mstore(0x60, 0) // Restore the zero slot to zero.
      mstore(0x40, m) // Restore the free memory pointer.
    }
  }

  function safeERC20Transfer(address token, address to, uint256 amount) internal {
    bytes4 transferFailed = ErrTransferFailed.selector;
    /// @solidity memory-safe-assembly
    assembly {
      mstore(0x14, to) // Store the `to` argument.
      mstore(0x34, amount) // Store the `amount` argument.
      // Store the function selector of `transfer(address,uint256)`.
      mstore(0x00, 0xa9059cbb000000000000000000000000)

      if iszero(
        and(
          // The arguments of `and` are evaluated from right to left.
          // Set success to whether the call reverted, if not we check it either
          // returned exactly 1 (can't just be non-zero data), or had no return data.
          or(eq(mload(0x00), 1), iszero(returndatasize())),
          call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
        )
      ) {
        // Store the function selector of `ErrTransferFailed()`.
        mstore(0x00, transferFailed)
        // Revert with (offset, size).
        revert(0x1c, 0x04)
      }
      // Restore the part of the free memory pointer that was overwritten.
      mstore(0x34, 0)
    }
  }

  function safeERC20Approve(address token, address to, uint256 amount) internal {
    bytes4 approveFailed = ErrApproveFailed.selector;
    /// @solidity memory-safe-assembly
    assembly {
      mstore(0x14, to) // Store the `to` argument.
      mstore(0x34, amount) // Store the `amount` argument.
      // Store the function selector of `approve(address,uint256)`.
      mstore(0x00, 0x095ea7b3000000000000000000000000)

      if iszero(
        and(
          // The arguments of `and` are evaluated from right to left.
          // Set success to whether the call reverted, if not we check it either
          // returned exactly 1 (can't just be non-zero data), or had no return data.
          or(eq(mload(0x00), 1), iszero(returndatasize())),
          call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
        )
      ) {
        // Store the function selector of `ErrApproveFailed()`.
        mstore(0x00, approveFailed)
        // Revert with (offset, size).
        revert(0x1c, 0x04)
      }
      // Restore the part of the free memory pointer that was overwritten.
      mstore(0x34, 0)
    }
  }

  /// @dev Returns the amount of ERC20 `token` owned by `account`.
  /// Returns zero if the `token` does not exist.
  function safeERC20balanceOf(address token, address account) internal view returns (uint256 amount) {
    /// @solidity memory-safe-assembly
    assembly {
      mstore(0x14, account) // Store the `account` argument.
      // Store the function selector of `balanceOf(address)`.
      mstore(0x00, 0x70a08231000000000000000000000000)
      amount := mul(
        mload(0x20),
        and(
          // The arguments of `and` are evaluated from right to left.
          gt(returndatasize(), 0x1f), // At least 32 bytes returned.
          staticcall(gas(), token, 0x10, 0x24, 0x20, 0x20)
        )
      )
    }
  }
}
