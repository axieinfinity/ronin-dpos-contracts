// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ContractType, AddressArrayUtils, IBridgeAdminOperator, BridgeAdminOperator } from "../../extensions/bridge-operator-governance/BridgeAdminOperator.sol";

contract MockBridgeAdminOperator is BridgeAdminOperator {
  //   constructor(
  //     address bridgeContract,
  //     uint256[] memory voteWeights,
  //     address[] memory governors,
  //     address[] memory bridgeOperators
  //   ) BridgeAdminOperator(bridgeContract, voteWeights, governors, bridgeOperators) {}

  constructor(address bridgeContract) {
    _setContract(ContractType.BRIDGE, bridgeContract);
  }
}
