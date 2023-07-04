// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { RoleAccess, ContractType, AddressArrayUtils, IBridgeOperatorManager, BridgeOperatorManager } from "../../extensions/bridge-operator-governance/BridgeOperatorManager.sol";

contract MockBridgeOperatorManager is BridgeOperatorManager {
  constructor(address admin, address bridgeContract) BridgeOperatorManager(0, 0, 0, admin, bridgeContract) {}
}
