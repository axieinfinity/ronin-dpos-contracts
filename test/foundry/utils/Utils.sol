// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { StdUtils } from "forge-std/StdUtils.sol";

import { PRBMathUtils } from "@prb/math/src/test/Utils.sol";

abstract contract Utils is StdUtils, PRBMathUtils {
  function getEmptyAddressArray() internal pure returns (address[] memory arr) {}
}
