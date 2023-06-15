// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ConditionalVersionControl } from "../../../utils/version-control/ConditionalVersionControl.sol";

contract MockConditionalVersionControl is ConditionalVersionControl {
  constructor(
    address proxyStorage,
    address currentVersion,
    address newVersion
  ) ConditionalVersionControl(proxyStorage, currentVersion, newVersion) {}

  function _isConditionMet() internal view override returns (bool) {
    return block.number > 100;
  }
}
