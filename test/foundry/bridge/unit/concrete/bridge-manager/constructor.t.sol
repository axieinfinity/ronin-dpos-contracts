// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17 <0.9.0;

import { console } from "forge-std/console.sol";
import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { IBridgeManagerEvents } from "@ronin/contracts/interfaces/bridge/events/IBridgeManagerEvents.sol";

import { BridgeManager_Unit_Concrete_Test } from "./BridgeManager.t.sol";

contract Constructor_BridgeManager_Unit_Concrete_Test is BridgeManager_Unit_Concrete_Test {
  function test_Constructor() external {
    // Expect the relevant event to be emitted.
    // bool[] memory statuses = new bool[](3);
    // statuses[0] = true;
    // statuses[1] = true;
    // statuses[2] = true;

    // vm.expectEmit();
    // emit IBridgeManagerEvents.BridgeOperatorsAdded({
    //   statuses: statuses,
    //   voteWeights: _voteWeights,
    //   governors: _governors,
    //   bridgeOperators: _bridgeOperators
    // });

    (address[] memory bridgeOperators, address[] memory governors, uint96[] memory voteWeights) = _getBridgeMembers();

    _assertBridgeMembers({
      comparingOperators: _bridgeOperators,
      expectingOperators: bridgeOperators,
      comparingGovernors: _governors,
      expectingGovernors: governors,
      comparingWeights: _voteWeights,
      expectingWeights: voteWeights
    });
    assertEq(_bridgeManager.totalBridgeOperator(), 3);
    assertEq(_bridgeManager.getTotalWeight(), _totalWeight);
  }

  function test_GetFullBridgeOperatorInfos() external {
    (
      address[] memory expectingBridgeOperators,
      address[] memory expectingGovernors,
      uint96[] memory expectingVoteWeights
    ) = _getBridgeMembers();

    (
      address[] memory returnedGovernors,
      address[] memory returnedBridgeOperators,
      uint96[] memory returnedVoteWeights
    ) = _bridgeManager.getFullBridgeOperatorInfos();

    _assertBridgeMembers({
      comparingOperators: returnedBridgeOperators,
      comparingGovernors: returnedGovernors,
      comparingWeights: returnedVoteWeights,
      expectingOperators: expectingBridgeOperators,
      expectingGovernors: expectingGovernors,
      expectingWeights: expectingVoteWeights
    });
  }
}
