// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibArrayUtils {
  function sum(bool[] memory arr) internal pure returns (uint256 total) {
    uint256 length = arr.length;
    for (uint256 i; i < length; ) {
      if (arr[i]) total++;
      unchecked {
        ++i;
      }
    }
  }

  function sum(uint256[] memory arr) internal pure returns (uint256 total) {
    uint256 length = arr.length;
    for (uint256 i; i < length; ) {
      total += arr[i];
      unchecked {
        ++i;
      }
    }
  }

  function sum(uint96[] memory arr) internal pure returns (uint256 total) {
    uint256[] memory arr256;
    assembly {
      arr256 := arr
    }

    return sum(arr256);
  }
}
