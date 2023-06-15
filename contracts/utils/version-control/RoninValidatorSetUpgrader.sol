// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ErrorHandler, ConditionalVersionControl } from "./ConditionalVersionControl.sol";
import { ITimingInfo } from "../../interfaces/validator/info-fragments/ITimingInfo.sol";

contract RoninValidatorSetUpgrader is ConditionalVersionControl {
  using ErrorHandler for bool;

  constructor(
    address proxyStorage,
    address currentVersion,
    address newVersion
  ) ConditionalVersionControl(proxyStorage, currentVersion, newVersion) {}

  function _isConditionMet() internal view override returns (bool) {
    (bool success, bytes memory returnOrRevertData) = _currentVersion.staticcall(
      abi.encodeCall(ITimingInfo.isPeriodEnding, ())
    );
    success.handleRevert(msg.sig, returnOrRevertData);
    return abi.decode(returnOrRevertData, (bool));
  }
}
