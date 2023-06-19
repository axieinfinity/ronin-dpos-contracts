// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ConditionalVersionControl } from "../../../extensions/version-control/ConditionalVersionControl.sol";

contract MockConditionalVersionControl is ConditionalVersionControl {
  modifier whenConditionsAreMet() override {
    _;
    if (_isConditionMet()) {
      try this.selfMigrate{ gas: _gasStipenedNoGrief() }() {} catch {}
    }
  }

  constructor(
    address proxyStorage_,
    address currentVersion_,
    address newVersion_
  ) ConditionalVersionControl(proxyStorage_, currentVersion_, newVersion_) {}

  function _getVersion() internal view override returns (address) {
    return _isConditionMet() ? newVersion : currentVersion;
  }

  function _isConditionMet() internal view returns (bool) {
    return block.number > 100;
  }
}
