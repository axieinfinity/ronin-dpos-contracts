// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ErrorHandler, ConditionalVersionControl } from "./ConditionalVersionControl.sol";
import { ITimingInfo } from "../../interfaces/validator/info-fragments/ITimingInfo.sol";

contract RoninValidatorSetUpgrader is ConditionalVersionControl {
  using ErrorHandler for bool;

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
    (bool success, bytes memory returnOrRevertData) = address(this).staticcall(
      abi.encodeCall(ITimingInfo.currentPeriod, ())
    );
    success.handleRevert(msg.sig, returnOrRevertData);
    uint256 currentPeriod = abi.decode(returnOrRevertData, (uint256));
    return currentPeriod > _currentPeriod;
  }
}
