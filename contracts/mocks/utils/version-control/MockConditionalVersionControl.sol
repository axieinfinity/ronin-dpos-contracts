// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ConditionalVersionControl } from "../../../utils/version-control/ConditionalVersionControl.sol";

contract MockConditionalVersionControl is ConditionalVersionControl {
  modifier whenConditionsAreMet() override {
    _;
    if (_isConditionMet()) {
      try this.selfMigrate{ gas: _gasStipenedNoGrief() }() {} catch {}
    }
  }

  constructor(
    address proxyStorage,
    address currentVersion,
    address newVersion
  ) ConditionalVersionControl(proxyStorage, currentVersion, newVersion) {}

  function _chooseVersion() internal view override returns (address) {
    return _isConditionMet() ? _newVersion : _currentVersion;
  }

  function _isConditionMet() internal view returns (bool) {
    return block.number > 100;
  }
}
