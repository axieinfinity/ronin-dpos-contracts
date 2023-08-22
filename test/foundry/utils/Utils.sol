// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { StdUtils } from "forge-std/StdUtils.sol";

import { PRBMathUtils } from "@prb/math/src/test/Utils.sol";

abstract contract Utils is StdUtils, PRBMathUtils {
  function getEmptyAddressArray() internal pure returns (address[] memory arr) {}

  function wrapAddress(address val) internal pure returns (address[] memory arr) {
    arr = new address[](1);
    arr[0] = val;
  }

  function unwrapAddress(address[] memory arr) internal pure returns (address val) {
    val = arr[0];
  }
}
