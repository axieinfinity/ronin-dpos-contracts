// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BaseDeploy, ContractKey } from "script/BaseDeploy.s.sol";
import { BridgeReward } from "@ronin/contracts/ronin/gateway/BridgeReward.sol";

contract BridgeRewardDeploy is BaseDeploy {
  function run() public virtual trySetUp returns (BridgeReward) {
    return BridgeReward(_deployProxy(ContractKey.BridgeReward, arguments()));
  }
}
