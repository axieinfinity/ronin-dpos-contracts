// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ConditionalVersionControl } from "./ConditionalVersionControl.sol";
import { ITimingInfo } from "../../interfaces/validator/info-fragments/ITimingInfo.sol";

contract RoninValidatorSetUpgrader is ConditionalVersionControl {
  uint256 private immutable _currentPeriod;

  constructor(
    uint256 currentPeriod,
    address proxyStorage,
    address currentVersion,
    address newVersion
  ) ConditionalVersionControl(proxyStorage, currentVersion, newVersion) {
    _currentPeriod = currentPeriod;
  }

  function _isConditionMet() internal view override returns (bool) {
    return ITimingInfo(address(this)).currentPeriod() > _currentPeriod;
  }
}
