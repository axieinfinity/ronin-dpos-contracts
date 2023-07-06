// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { RoleAccess, ContractType, AddressArrayUtils, IBridgeOperatorManager, BridgeOperatorManager } from "../../extensions/bridge-operator-governance/BridgeOperatorManager.sol";

contract MockBridgeOperatorManager is BridgeOperatorManager {
  constructor(
    address admin,
    uint256[] memory voteWeights,
    address[] memory governors,
    address[] memory bridgeOperators
  ) payable BridgeOperatorManager(0, 0, 0, admin, voteWeights, governors, bridgeOperators) {}
}
