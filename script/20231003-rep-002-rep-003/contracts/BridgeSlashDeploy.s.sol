// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BaseDeploy, ContractKey } from "script/BaseDeploy.s.sol";
import { BridgeSlash } from "@ronin/contracts/ronin/gateway/BridgeSlash.sol";

contract BridgeSlashDeploy is BaseDeploy {
  function run() public virtual trySetUp returns (BridgeSlash) {
    return BridgeSlash(_deployProxy(ContractKey.BridgeSlash));
  }
}
