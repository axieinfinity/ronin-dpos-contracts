// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

library AddressArrayUtils {
  /**
   * Returns whether or not there's a duplicate. Runs in O(n^2).
   * @param A Array to search
   * @return Returns true if duplicate, false otherwise
   */
  function hasDuplicate(address[] memory A) internal pure returns (bool) {
    if (A.length == 0) {
      return false;
    }
    for (uint256 i = 0; i < A.length - 1; i++) {
      for (uint256 j = i + 1; j < A.length; j++) {
        if (A[i] == A[j]) {
          return true;
        }
      }
    }
    return false;
  }

  /**
   * Returns whether or not all elements in the array are all equal. Runs in O(n).
   * @param A Array to search
   * @return Returns true if all equal, false otherwise
   */
  function hasAllEqual(address[] memory A) internal pure returns (bool) {
    if (A.length == 0) {
      return true;
    }
    for (uint i = 0; i < A.length - 1; i++) {
      if (A[i] != A[i + 1]) {
        return false;
      }
    }
    return true;
  }
}
