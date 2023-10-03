// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ConditionalImplementControl } from "@ronin/contracts/extensions/version-control/ConditionalImplementControl.sol";
import { RoninValidatorSet } from "@ronin/contracts/ronin/validator/RoninValidatorSet.sol";
import { BaseDeploy, ContractKey } from "script/BaseDeploy.s.sol";
import { FastFinalityTrackingDeploy } from "./FastFinalityTrackingDeploy.s.sol";

contract RoninValidatorSetTimedMigratorUpgrade is BaseDeploy {
  function _injectDependencies() internal override {
    _setDependencyDeployScript(ContractKey.FastFinalityTracking, new FastFinalityTrackingDeploy());
  }

  function run() public virtual trySetUp returns (RoninValidatorSet) {
    address payable proxy = _config.getAddressFromCurrentNetwork(ContractKey.RoninValidatorSet);
    address proxyAdmin = _getProxyAdmin(proxy);
    address prevImpl = _getProxyImplementation(proxy);
    address newImpl = _deployLogic(ContractKey.RoninValidatorSet, EMPTY_ARGS);
    address switcher = _deployLogic(ContractKey.RoninValidatorSetTimedMigrator, abi.encode(proxy, prevImpl, newImpl));

    bytes[] memory callDatas = new bytes[](2);
    callDatas[0] = abi.encodeCall(RoninValidatorSet.initializeV2, ());
    callDatas[1] = abi.encodeCall(
      RoninValidatorSet.initializeV3,
      (loadContractOrDeploy(ContractKey.FastFinalityTracking))
    );
    return
      RoninValidatorSet(
        _upgradeRaw(proxyAdmin, proxy, switcher, abi.encodeCall(ConditionalImplementControl.setCallDatas, (callDatas)))
      );
  }
}
