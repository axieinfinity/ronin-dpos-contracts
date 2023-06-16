// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ConditionalVersionControl } from "./ConditionalVersionControl.sol";
import { ITimingInfo } from "../../interfaces/validator/info-fragments/ITimingInfo.sol";
import { ICoinbaseExecution } from "../../interfaces/validator/ICoinbaseExecution.sol";

contract RoninValidatorSetTimedMigrator is ConditionalVersionControl {
  modifier whenConditionsAreMet() override {
    if (msg.sig == ICoinbaseExecution.wrapUpEpoch.selector) {
      uint256 currentPeriod = _getCurrentPeriod();
      _;
      if (currentPeriod != _getCurrentPeriod()) {
        try this.selfMigrate{ gas: _gasStipenedNoGrief() }() {} catch {}
      }
    } else {
      _;
    }
  }

  constructor(
    address proxyStorage,
    address currentVersion,
    address newVersion
  ) ConditionalVersionControl(proxyStorage, currentVersion, newVersion) {}

  function _chooseVersion() internal view override returns (address) {
    return _currentVersion;
  }

  function _getCurrentPeriod() private view returns (uint256) {
    return ITimingInfo(address(this)).currentPeriod();
  }
}
