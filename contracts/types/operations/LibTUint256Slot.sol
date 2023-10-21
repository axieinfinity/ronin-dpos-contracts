// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { TUint256Slot } from "../Types.sol";

/**
 * @title LibTUint256Slot
 * @dev Library for handling unsigned 256-bit integers.
 */
library LibTUint256Slot {
  /// @dev value is equal to bytes4(keccak256("Panic(uint256)"))
  /// @dev see: https://github.com/foundry-rs/forge-std/blob/master/src/StdError.sol
  uint256 private constant PANIC_ERROR_SIGNATURE = 0x4e487b71;
  /// @dev error code for {Arithmetic over/underflow} error
  uint256 private constant ARITHMETIC_ERROR_CODE = 0x11;
  /// @dev error code for {Division or modulo by 0} error
  uint256 private constant DIVISION_ERROR_CODE = 0x12;

  /**
   * @dev Loads the value of the TUint256Slot variable.
   * @param self The TUint256Slot variable.
   * @return val The loaded value.
   */
  function load(TUint256Slot self) internal view returns (uint256 val) {
    assembly {
      val := sload(self)
    }
  }

  /**
   * @dev Stores a value into the TUint256Slot variable.
   * @param self The TUint256Slot variable.
   * @param other The value to be stored.
   */
  function store(TUint256Slot self, uint256 other) internal {
    assembly {
      sstore(self, other)
    }
  }

  /**
   * @dev Multiplies the TUint256Slot variable by a given value.
   * @param self The TUint256Slot variable.
   * @param other The value to multiply by.
   * @return res The resulting value after multiplication.
   */
  function mul(TUint256Slot self, uint256 other) internal view returns (uint256 res) {
    assembly {
      let storedVal := sload(self)
      if iszero(iszero(storedVal)) {
        res := mul(storedVal, other)

        // Overflow check
        if iszero(eq(other, div(res, storedVal))) {
          // Store 4 bytes the function selector of Panic(uint256)
          // Equivalent to revert Panic(uint256)
          mstore(0x00, PANIC_ERROR_SIGNATURE)
          // Store 4 bytes of division error code in the next slot
          mstore(0x20, ARITHMETIC_ERROR_CODE)
          // Revert 36 bytes of error starting from 0x1c
          revert(0x1c, 0x24)
        }
      }
    }
  }

  /**
   * @dev Divides the TUint256Slot variable by a given value.
   * @param self The TUint256Slot variable.
   * @param other The value to divide by.
   * @return res The resulting value after division.
   */
  function div(TUint256Slot self, uint256 other) internal view returns (uint256 res) {
    assembly {
      let storedVal := sload(self)
      // revert if divide by zero
      if iszero(other) {
        // Store 4 bytes the function selector of Panic(uint256)
        // Equivalent to revert Panic(uint256)
        mstore(0x00, PANIC_ERROR_SIGNATURE)
        // Store 4 bytes of division error code in the next slot
        mstore(0x20, DIVISION_ERROR_CODE)
        // Revert 36 bytes of error starting from 0x1c
        revert(0x1c, 0x24)
      }
      res := div(storedVal, other)
    }
  }

  /**
   * @dev Subtracts a given value from the TUint256Slot variable.
   * @param self The TUint256Slot variable.
   * @param other The value to subtract.
   * @return res The resulting value after subtraction.
   */
  function sub(TUint256Slot self, uint256 other) internal view returns (uint256 res) {
    assembly {
      let storedVal := sload(self)

      // Underflow check
      if lt(storedVal, other) {
        // Store 4 bytes the function selector of Panic(uint256)
        // Equivalent to revert Panic(uint256)
        mstore(0x00, PANIC_ERROR_SIGNATURE)
        // Store 4 bytes of division error code in the next slot
        mstore(0x20, ARITHMETIC_ERROR_CODE)
        // Revert 36 bytes of error starting from 0x1c
        revert(0x1c, 0x24)
      }

      res := sub(storedVal, other)
    }
  }

  /**
   * @dev Adds a given value to the TUint256Slot variable.
   * @param self The TUint256Slot variable.
   * @param other The value to add.
   * @return res The resulting value after addition.
   */
  function add(TUint256Slot self, uint256 other) internal view returns (uint256 res) {
    assembly {
      let storedVal := sload(self)
      res := add(storedVal, other)

      // Overflow check
      if lt(res, other) {
        // Store 4 bytes the function selector of Panic(uint256)
        // Equivalent to revert Panic(uint256)
        mstore(0x00, PANIC_ERROR_SIGNATURE)
        // Store 4 bytes of division error code in the next slot
        mstore(0x20, ARITHMETIC_ERROR_CODE)
        // Revert 36 bytes of error starting from 0x1c
        revert(0x1c, 0x24)
      }
    }
  }

  /**
   * @dev Increments the TUint256Slot variable by 1 and returns the new value.
   * @param self The TUint256Slot variable.
   * @return res The resulting value after incrementing.
   */
  function preIncrement(TUint256Slot self) internal returns (uint256 res) {
    res = addAssign(self, 1);
  }

  /**
   * @dev Increments the TUint256Slot variable by 1 and returns the original value.
   * @param self The TUint256Slot variable.
   * @return res The original value before incrementing.
   */
  function postIncrement(TUint256Slot self) internal returns (uint256 res) {
    res = load(self);
    store(self, res + 1);
  }

  /**
   * @dev Decrements the TUint256Slot variable by 1 and returns the new value.
   * @param self The TUint256Slot variable.
   * @return res The resulting value after decrementing.
   */
  function preDecrement(TUint256Slot self) internal returns (uint256 res) {
    res = subAssign(self, 1);
  }

  /**
   * @dev Decrements the TUint256Slot variable by 1 and returns the new value.
   * @param self The TUint256Slot variable.
   * @return res The resulting value before decrementing.
   */
  function postDecrement(TUint256Slot self) internal returns (uint256 res) {
    res = load(self);
    store(self, res - 1);
  }

  /**
   * @dev Adds a given value to the TUint256Slot variable and stores the result.
   * @param self The TUint256Slot variable.
   * @param other The value to add.
   * @return res The resulting value after addition and storage.
   */
  function addAssign(TUint256Slot self, uint256 other) internal returns (uint256 res) {
    store(self, res = add(self, other));
  }

  /**
   * @dev Subtracts a given value from the TUint256Slot variable and stores the result.
   * @param self The TUint256Slot variable.
   * @param other The value to subtract.
   * @return res The resulting value after subtraction and storage.
   */
  function subAssign(TUint256Slot self, uint256 other) internal returns (uint256 res) {
    store(self, res = sub(self, other));
  }
}
