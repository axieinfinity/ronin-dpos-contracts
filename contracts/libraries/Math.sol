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
  function inRange(uint256 c, uint256 a, uint256 b) internal pure returns (bool) {
    return a <= c && c <= b;
  }

  /**
   * @dev Returns whether two inclusive ranges [x1;x2] and [y1;y2] overlap.
   */
  function twoRangeOverlap(uint256 x1, uint256 x2, uint256 y1, uint256 y2) internal pure returns (bool) {
    return x1 <= y2 && y1 <= x2;
  }

  /**
   * @dev Returns value of a + b; in case result is larger than upperbound, upperbound is returned.
   */
  function addWithUpperbound(uint256 a, uint256 b, uint256 upperbound) internal pure returns (uint256) {
    return min(a + b, upperbound);
  }

  /**
   * @dev Returns value of a - b; in case of negative result, 0 is returned.
   */
  function subNonNegative(uint256 a, uint256 b) internal pure returns (uint256) {
    return a > b ? a - b : 0;
  }

  /**
   * @dev Returns value of `a + zeroable` if zerobale is not 0; otherwise, return 0.
   */
  function addIfNonZero(uint256 a, uint256 zeroable) internal pure returns (uint256) {
    return zeroable != 0 ? a + zeroable : 0;
  }
}
