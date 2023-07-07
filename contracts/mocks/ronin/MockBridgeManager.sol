// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { RoleAccess, ContractType, AddressArrayUtils, IBridgeManager, BridgeManager } from "../../extensions/bridge-operator-governance/BridgeManager.sol";

contract MockBridgeManager is BridgeManager {
  constructor(
    address bridgeContract,
    uint256[] memory voteWeights,
    address[] memory governors,
    address[] memory bridgeOperators
  ) payable BridgeManager(0, 0, 0, bridgeContract, voteWeights, governors, bridgeOperators) {}

  function _requireSelfCall() internal view override {}
}
