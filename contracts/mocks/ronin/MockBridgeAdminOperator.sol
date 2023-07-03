// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ContractType, AddressArrayUtils, IBridgeAdminOperator, BridgeAdminOperator } from "../../extensions/bridge-operator-governance/BridgeAdminOperator.sol";

contract MockBridgeAdminOperator is BridgeAdminOperator {
  constructor(address admin, address bridgeContract) BridgeAdminOperator(admin, bridgeContract) {}
}
