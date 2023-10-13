// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BaseDeploy, ContractKey } from "script/BaseDeploy.s.sol";
import { RoninBridgeManager, GlobalProposal } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { BridgeSlashDeploy } from "./BridgeSlashDeploy.s.sol";

contract RoninBridgeManagerDeploy is BaseDeploy {
  function _injectDependencies() internal override {
    _setDependencyDeployScript(ContractKey.BridgeSlash, new BridgeSlashDeploy());
  }

  function _defaultArguments() internal override returns (bytes memory args) {
    // register BridgeSlash as callback receiver
    address[] memory callbackRegisters = new address[](1);
    // load BridgeSlash address
    callbackRegisters[0] = loadContractOrDeploy(ContractKey.BridgeSlash);

    address[] memory operators = new address[](1);
    operators[0] = makeAccount("detach-operator-1").addr;

    address[] memory governors = new address[](1);
    governors[0] = makeAccount("detach-governor-1").addr;

    uint96[] memory weights = new uint96[](1);
    weights[0] = 100;

    GlobalProposal.TargetOption[] memory targetOptions;
    address[] memory targets;

    return
      abi.encode(
        2, //DEFAULT_NUMERATOR,
        4, //DEFAULT_DENOMINATOR,
        block.chainid,
        5 minutes, // DEFAULT_EXPIRY_DURATION,
        _config.getAddressFromCurrentNetwork(ContractKey.RoninGatewayV3),
        callbackRegisters,
        operators,
        governors,
        weights,
        targetOptions,
        targets
      );
  }

  function run() public virtual trySetUp returns (RoninBridgeManager) {
    return RoninBridgeManager(_deployImmutable(ContractKey.RoninBridgeManager));
  }
}
