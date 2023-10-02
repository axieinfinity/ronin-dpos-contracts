// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BaseDeploy, ContractKey } from "script/BaseDeploy.s.sol";
import { FastFinalityTracking } from "@ronin/contracts/ronin/fast-finality/FastFinalityTracking.sol";

contract FastFinalityTrackingDeploy is BaseDeploy {
  function _defaultArguments() internal view override returns (bytes memory args) {
    args = abi.encodeCall(
      FastFinalityTracking.initialize,
      _config.getAddressFromCurrentNetwork(ContractKey.RoninValidatorSet)
    );
  }

  function run() public virtual trySetUp returns (FastFinalityTracking) {
    return FastFinalityTracking(_deployProxy(ContractKey.FastFinalityTracking, arguments()));
  }
}
