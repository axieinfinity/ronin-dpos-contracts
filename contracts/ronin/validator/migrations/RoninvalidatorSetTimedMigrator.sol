// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ConditionalVersionControl } from "../../../extensions/version-control/ConditionalVersionControl.sol";
import { ITimingInfo } from "../../../interfaces/validator/info-fragments/ITimingInfo.sol";
import { ICoinbaseExecution } from "../../../interfaces/validator/ICoinbaseExecution.sol";

/**
 * @title RoninValidatorSetTimedMigrator
 * @dev A contract that facilitates timed migration of the Ronin validator set using conditional version control.
 */
contract RoninValidatorSetTimedMigrator is ConditionalVersionControl {
  /**
   * @dev Modifier that executes the function when conditions are met.
   * If the function is {wrapUpEpoch} from {ICoinbaseExecution},
   * it checks the current period before and after execution.
   * If they differ, it triggers the {selfMigrate} function.
   */
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

  /**
   * @dev Constructs the {RoninValidatorSetTimedMigrator} contract.
   * @param proxyStorage_ The address of the proxy storage contract.
   * @param currentVersion_ The address of the current contract implementation.
   * @param newVersion_ The address of the new contract implementation.
   */
  constructor(
    address proxyStorage_,
    address currentVersion_,
    address newVersion_
  ) ConditionalVersionControl(proxyStorage_, currentVersion_, newVersion_) {}

  /**
   * @dev Internal function to choose the current version of the contract implementation.
   * @return The address of the current version implementation.
   */
  function _getVersion() internal view override returns (address) {
    return currentVersion;
  }

  /**
   * @dev Internal function to get the current period from ITimingInfo.
   * @return The current period.
   */
  function _getCurrentPeriod() private view returns (uint256) {
    return ITimingInfo(address(this)).currentPeriod();
  }
}
