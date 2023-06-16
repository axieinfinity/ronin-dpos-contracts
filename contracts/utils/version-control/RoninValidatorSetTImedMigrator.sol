// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ConditionalVersionControl } from "./ConditionalVersionControl.sol";
import { ITimingInfo } from "../../interfaces/validator/info-fragments/ITimingInfo.sol";
import { ICoinbaseExecution } from "../../interfaces/validator/ICoinbaseExecution.sol";

contract RoninValidatorSetTimedMigrator is ConditionalVersionControl {
  /// @dev value is equal to keccak256("@ronin.dpos.utils.version-control.RVTimedMigrator.isPeriodEnding.slot")
  bytes32 private constant _SLOT = 0x56663dc009889135c9a870af5d0c2e5271b9595765451175f9f0a515d04a31ff;

  modifier whenWrapUpEpoch() {
    if (msg.sig == ICoinbaseExecution.wrapUpEpoch.selector) {
      uint256 currentPeriod = _getCurrentPeriod();
      _;
      if (currentPeriod != _getCurrentPeriod()) {
        this.markPeriodAsEnded();
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

  function markPeriodAsEnded() external onlyDelegateFromProxyStorage onlySelfCall {
    assembly {
      sstore(_SLOT, 1)
    }
  }

  function _dispatchCall(address version) internal override whenWrapUpEpoch returns (bytes memory) {
    return super._dispatchCall(version);
  }

  function _getCurrentPeriod() private view returns (uint256) {
    return ITimingInfo(address(this)).currentPeriod();
  }

  function _isConditionMet() internal view override returns (bool) {
    return _isPeriodAlreadyEnded();
  }

  function _isPeriodAlreadyEnded() private view returns (bool ended) {
    assembly {
      ended := iszero(iszero(sload(_SLOT)))
    }
  }
}
