// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ConditionalImplementControl } from "../../../extensions/version-control/ConditionalImplementControl.sol";

contract MockConditionalImplementControl is ConditionalImplementControl {
  constructor(
    address proxyStorage_,
    address currentVersion_,
    address newVersion_
  ) ConditionalImplementControl(proxyStorage_, currentVersion_, newVersion_) {}

  function _isConditionMet() internal view override returns (bool) {
    return block.number > 100;
  }
}
