// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

library Math {
  /**
   * @dev Returns the largest of two numbers.
   */
  function max(uint256 a, uint256 b) internal pure returns (uint256) {
    return a >= b ? a : b;
  }

  /**
   * @dev Returns the smallest of two numbers.
   */
  function min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
  }

  /**
   * @dev Returns whether the number `c` is in range of [a; b].
   */
  function inRange(
    uint256 c,
    uint256 a,
    uint256 b
  ) internal pure returns (bool) {
    return a <= c && c <= b;
  }
}
