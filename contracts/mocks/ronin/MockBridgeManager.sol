// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { RoleAccess, ContractType, AddressArrayUtils, IBridgeManager, BridgeManager } from "../../extensions/bridge-operator-governance/BridgeManager.sol";

contract MockBridgeManager is BridgeManager {
  constructor(
    address bridgeContract,
    address[] memory bridgeOperators,
    address[] memory governors,
    uint256[] memory voteWeights
  ) payable BridgeManager(0, 0, 0, bridgeContract, bridgeOperators, governors, voteWeights) {}

  function _requireSelfCall() internal view override {}
}
