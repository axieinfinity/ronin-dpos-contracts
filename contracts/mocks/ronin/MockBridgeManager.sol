// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { RoleAccess, ContractType, AddressArrayUtils, IBridgeManager, BridgeManager } from "../../extensions/bridge-operator-governance/BridgeManager.sol";

contract MockBridgeManager is BridgeManager {
  constructor(
    address[] memory bridgeOperators,
    address[] memory governors,
    uint96[] memory voteWeights
  ) payable BridgeManager(0, 0, 0, address(0), _getEmptyAddressArray(), bridgeOperators, governors, voteWeights) {}

  function _getEmptyAddressArray() internal pure returns (address[] memory arr) {}
}
