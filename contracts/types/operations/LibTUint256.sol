// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { TUint256 } from "../Types.sol";

/**
 * @title LibTUint256
 * @dev Library for handling unsigned 256-bit integers.
 */
library LibTUint256 {
  /**
   * @dev Loads the value of the TUint256 variable.
   * @param self The TUint256 variable.
   * @return val The loaded value.
   */
  function load(TUint256 self) internal view returns (uint256 val) {
    assembly {
      val := sload(self)
    }
  }

  /**
   * @dev Stores a value into the TUint256 variable.
   * @param self The TUint256 variable.
   * @param b The value to be stored.
   * @return res The stored value.
   */
  function store(TUint256 self, uint256 b) internal returns (uint256 res) {
    assembly {
      sstore(self, b)
      res := b
    }
  }

  /**
   * @dev Multiplies the TUint256 variable by a given value.
   * @param self The TUint256 variable.
   * @param b The value to multiply by.
   * @return res The resulting value after multiplication.
   */
  function mul(TUint256 self, uint256 b) internal view returns (uint256 res) {
    assembly {
      let storedVal := sload(self)
      res := mul(storedVal, b)

      // Overflow check
      if iszero(eq(b, div(res, storedVal))) {
        revert(0, 0)
      }
    }
  }

  /**
   * @dev Divides the TUint256 variable by a given value.
   * @param self The TUint256 variable.
   * @param b The value to divide by.
   * @return res The resulting value after division.
   */
  function div(TUint256 self, uint256 b) internal view returns (uint256 res) {
    assembly {
      let storedVal := sload(self)
      res := div(storedVal, b)
    }
  }

  /**
   * @dev Subtracts a given value from the TUint256 variable.
   * @param self The TUint256 variable.
   * @param b The value to subtract.
   * @return res The resulting value after subtraction.
   */
  function sub(TUint256 self, uint256 b) internal view returns (uint256 res) {
    assembly {
      let storedVal := sload(self)

      // Underflow check
      if lt(storedVal, b) {
        revert(0, 0)
      }

      res := sub(storedVal, b)
    }
  }

  /**
   * @dev Adds a given value to the TUint256 variable.
   * @param self The TUint256 variable.
   * @param b The value to add.
   * @return res The resulting value after addition.
   */
  function add(TUint256 self, uint256 b) internal view returns (uint256 res) {
    assembly {
      let storedVal := sload(self)
      res := add(storedVal, b)

      // Overflow check
      if lt(res, b) {
        revert(0, 0)
      }
    }
  }

  /**
   * @dev Increments the TUint256 variable by 1 and returns the new value.
   * @param self The TUint256 variable.
   * @return res The resulting value after incrementing.
   */
  function preIncrement(TUint256 self) internal returns (uint256 res) {
    res = addAssign(self, 1);
  }

  /**
   * @dev Increments the TUint256 variable by 1 and returns the original value.
   * @param self The TUint256 variable.
   * @return res The original value before incrementing.
   */
  function postIncrement(TUint256 self) internal returns (uint256 res) {
    res = add(self, 1);
    addAssign(self, 1);
  }

  /**
   * @dev Decrements the TUint256 variable by 1 and returns the new value.
   * @param self The TUint256 variable.
   * @return res The resulting value after decrementing.
   */
  function decrement(TUint256 self) internal returns (uint256 res) {
    res = subAssign(self, 1);
  }

  /**
   * @dev Adds a given value to the TUint256 variable and stores the result.
   * @param self The TUint256 variable.
   * @param b The value to add.
   * @return res The resulting value after addition and storage.
   */
  function addAssign(TUint256 self, uint256 b) internal returns (uint256 res) {
    res = store(self, add(self, b));
  }

  /**
   * @dev Subtracts a given value from the TUint256 variable and stores the result.
   * @param self The TUint256 variable.
   * @param b The value to subtract.
   * @return res The resulting value after subtraction and storage.
   */
  function subAssign(TUint256 self, uint256 b) internal returns (uint256 res) {
    res = store(self, sub(self, b));
  }
}
