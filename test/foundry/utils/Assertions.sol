// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.21;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { PRBMathAssertions } from "@prb/math/src/test/Assertions.sol";

abstract contract Assertions is PRBTest, PRBMathAssertions {
  event LogNamedArray(string key, uint96[] value);

  /// @dev Tests that `a` and `b` are equal. If they are not, the test fails.
  /// Works by comparing the `keccak256` hashes of the arrays, which is faster than iterating over the elements.
  function assertEq(uint96[] memory a, uint96[] memory b) internal virtual {
    if (!(keccak256(abi.encode(a)) == keccak256(abi.encode(b)))) {
      emit PRBTest.Log("Error: a == b not satisfied [uint96[]]");
      emit LogNamedArray("   Left", a);
      emit LogNamedArray("  Right", b);
      PRBTest.fail();
    }
  }

  /// @dev Tests that `a` and `b` are equal. If they are not, the test fails with the error message `err`.
  /// Works by comparing the `keccak256` hashes of the arrays, which is faster than iterating over the elements.
  function assertEq(uint96[] memory a, uint96[] memory b, string memory err) internal virtual {
    if (!(keccak256(abi.encode(a)) == keccak256(abi.encode(b)))) {
      emit PRBTest.LogNamedString("Error", err);
      assertEq(a, b);
    }
  }
}
