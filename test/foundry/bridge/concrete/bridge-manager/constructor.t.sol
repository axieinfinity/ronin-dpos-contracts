// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17 <0.9.0;

import { console } from "forge-std/console.sol";
import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";

import { BridgeManager_Unit_Concrete_Test } from "./BridgeManager.t.sol";

contract Constructor_BridgeManager_Unit_Concrete_Test is BridgeManager_Unit_Concrete_Test {
  function test_Constructor() external {
    // Expect the relevant event to be emitted.
    // vm.expectEmit();
    // emit TransferAdmin({ oldAdmin: address(0), newAdmin: users.admin });

    address[] memory bridgeOperators = _bridgeManager.getBridgeOperators();
    address[] memory governors = _bridgeManager.getGovernors();

    assertEq(bridgeOperators, _bridgeOperators, "wrong bridge operators");
    assertEq(_bridgeManager.getGovernors(), governors, "wrong governors");
    assertEq(_bridgeManager.getGovernorWeights(governors), _voteWeights, "wrong weights");
  }
}
