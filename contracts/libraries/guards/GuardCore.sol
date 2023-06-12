// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract GuardCore {
  /**
   * | GuardType      | Bit position | Bit length | Explanation                                                     |
   * |----------------|--------------|------------|-----------------------------------------------------------------|
   * | PAUSER_BIT     | 0            | 1          | Flag indicating whether the contract is paused or not.          |
   * | REENTRANCY_BIT | 1            | 1          | Flag indicating whether the reentrancy guard is on or off.      |
   * | INITIALIZE_BIT | 2            | 1          | Flag indicating whether the origin guard is initialized or not. |
   * | ORIGIN_ADDRESS | 3            | 160        | Bits to store the origin address for delegate call guard.       |
   */
  enum GuardType {
    PAUSER_BIT,
    REENTRANCY_BIT,
    INITIALIZE_BIT,
    ORIGIN_ADDRESS
  }

  /**
   * @dev Returns the bit position of a guard type.
   *
   * Requirement:
   * - Each guard type must have a different bit position.
   * - The position of the guard types must not collide with each other.
   *
   */
  function _getBitPos(GuardType _type) internal pure virtual returns (uint8 _pos) {
    assembly {
      _pos := _type
    }
  }

  /**
   * @dev Returns the guard slot to store all of the guard types.
   */
  function _guardSlot() internal pure virtual returns (bytes32);
}
