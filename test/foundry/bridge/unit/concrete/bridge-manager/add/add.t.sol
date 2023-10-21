// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17 <0.9.0;

import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";

import "@ronin/contracts/utils/CommonErrors.sol";
import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";

import { BridgeManager_Unit_Concrete_Test } from "../BridgeManager.t.sol";

contract Add_Unit_Concrete_Test is BridgeManager_Unit_Concrete_Test {
  function setUp() public virtual override {
    BridgeManager_Unit_Concrete_Test.setUp();
    vm.startPrank({ msgSender: address(_bridgeManager) });
  }

  function test_RevertWhen_NotSelfCall() external {
    // Prepare data
    (
      address[] memory addingOperators,
      address[] memory addingGovernors,
      uint96[] memory addingWeights
    ) = _generateNewOperators();

    // Make the caller not self-call.
    changePrank({ msgSender: _bridgeOperators[0] });

    // Run the test.
    vm.expectRevert(abi.encodeWithSelector(ErrOnlySelfCall.selector, IBridgeManager.addBridgeOperators.selector));
    _bridgeManager.addBridgeOperators(addingWeights, addingGovernors, addingOperators);
  }

  function test_RevertWhen_ThreeInputArrayLengthMismatch() external {
    // Prepare data
    (
      address[] memory addingOperators,
      address[] memory addingGovernors,
      uint96[] memory addingWeights
    ) = _generateNewOperators();

    uint length = addingOperators.length;

    assembly {
      mstore(addingOperators, add(length, 1))
    }
    vm.expectRevert(abi.encodeWithSelector(ErrLengthMismatch.selector, IBridgeManager.addBridgeOperators.selector));
    _bridgeManager.addBridgeOperators(addingWeights, addingGovernors, addingOperators);

    assembly {
      mstore(addingOperators, length)
      mstore(addingGovernors, add(length, 1))
    }
    vm.expectRevert(abi.encodeWithSelector(ErrLengthMismatch.selector, IBridgeManager.addBridgeOperators.selector));
    _bridgeManager.addBridgeOperators(addingWeights, addingGovernors, addingOperators);

    assembly {
      mstore(addingGovernors, length)
      mstore(addingWeights, add(length, 1))
    }
    vm.expectRevert(abi.encodeWithSelector(ErrLengthMismatch.selector, IBridgeManager.addBridgeOperators.selector));
    _bridgeManager.addBridgeOperators(addingWeights, addingGovernors, addingOperators);
  }

  function test_RevertWhen_VoteWeightIsZero() external {
    // Prepare data
    (
      address[] memory addingOperators,
      address[] memory addingGovernors,
      uint96[] memory addingWeights
    ) = _generateNewOperators();

    addingWeights[0] = 0;
    vm.expectRevert(abi.encodeWithSelector(ErrInvalidVoteWeight.selector, IBridgeManager.addBridgeOperators.selector));
    _bridgeManager.addBridgeOperators(addingWeights, addingGovernors, addingOperators);
  }

  function test_RevertWhen_BridgeOperatorAddressIsZero() external {
    // Prepare data
    (
      address[] memory addingOperators,
      address[] memory addingGovernors,
      uint96[] memory addingWeights
    ) = _generateNewOperators();

    addingOperators[0] = address(0);
    vm.expectRevert(abi.encodeWithSelector(ErrZeroAddress.selector, IBridgeManager.addBridgeOperators.selector));
    _bridgeManager.addBridgeOperators(addingWeights, addingGovernors, addingOperators);
  }

  function test_RevertWhen_GovernorAddressIsZero() external {
    // Prepare data
    (
      address[] memory addingOperators,
      address[] memory addingGovernors,
      uint96[] memory addingWeights
    ) = _generateNewOperators();

    addingGovernors[0] = address(0);
    vm.expectRevert(abi.encodeWithSelector(ErrZeroAddress.selector, IBridgeManager.addBridgeOperators.selector));
    _bridgeManager.addBridgeOperators(addingWeights, addingGovernors, addingOperators);
  }

  function test_AddOperators_DuplicatedGovernor() external assertStateNotChange {
    (
      address[] memory addingOperators,
      address[] memory addingGovernors,
      uint96[] memory addingWeights
    ) = _generateNewOperators();

    addingGovernors[0] = _governors[0];
    bool[] memory addeds = _bridgeManager.addBridgeOperators(addingWeights, addingGovernors, addingOperators);
    bool[] memory expectedAddeds = new bool[](1);
    expectedAddeds[0] = false;
    assertEq(addeds, expectedAddeds);
  }

  function test_AddOperators_DuplicatedBridgeOperator() external assertStateNotChange {
    (
      address[] memory addingOperators,
      address[] memory addingGovernors,
      uint96[] memory addingWeights
    ) = _generateNewOperators();

    addingOperators[0] = _bridgeOperators[0];
    bool[] memory addeds = _bridgeManager.addBridgeOperators(addingWeights, addingGovernors, addingOperators);
    bool[] memory expectedAddeds = new bool[](1);
    expectedAddeds[0] = false;
    assertEq(addeds, expectedAddeds);
  }

  function test_AddOperators_DuplicatedGovernorWithExistedBridgeOperator() external assertStateNotChange {
    (
      address[] memory addingOperators,
      address[] memory addingGovernors,
      uint96[] memory addingWeights
    ) = _generateNewOperators();

    addingGovernors[0] = _bridgeOperators[0];
    bool[] memory addeds = _bridgeManager.addBridgeOperators(addingWeights, addingGovernors, addingOperators);
    bool[] memory expectedAddeds = new bool[](1);
    expectedAddeds[0] = false;
    assertEq(addeds, expectedAddeds);
  }

  function test_AddOperators_DuplicatedBridgeOperatorWithExistedGovernor() external assertStateNotChange {
    (
      address[] memory addingOperators,
      address[] memory addingGovernors,
      uint96[] memory addingWeights
    ) = _generateNewOperators();

    addingOperators[0] = _governors[0];
    bool[] memory addeds = _bridgeManager.addBridgeOperators(addingWeights, addingGovernors, addingOperators);
    bool[] memory expectedAddeds = new bool[](1);
    expectedAddeds[0] = false;
    assertEq(addeds, expectedAddeds);
  }

  function test_AddOperators_AllInfoIsValid() external {
    // Get before test state
    (
      address[] memory beforeBridgeOperators,
      address[] memory beforeGovernors,
      uint96[] memory beforeVoteWeights
    ) = _getBridgeMembers();

    (
      address[] memory addingOperators,
      address[] memory addingGovernors,
      uint96[] memory addingWeights
    ) = _generateNewOperators();

    bool[] memory addeds = _bridgeManager.addBridgeOperators(addingWeights, addingGovernors, addingOperators);
    bool[] memory expectedAddeds = new bool[](1);
    expectedAddeds[0] = true;
    assertEq(addeds, expectedAddeds);

    // Compare after and before state
    (
      address[] memory afterBridgeOperators,
      address[] memory afterGovernors,
      uint96[] memory afterVoteWeights
    ) = _getBridgeMembers();
    _totalWeight += addingWeights[0];

    uint extendedLength = beforeBridgeOperators.length + 1;
    assembly {
      mstore(beforeBridgeOperators, extendedLength)
      mstore(beforeGovernors, extendedLength)
      mstore(beforeVoteWeights, extendedLength)
    }

    beforeBridgeOperators[3] = addingOperators[0];
    beforeGovernors[3] = addingGovernors[0];
    beforeVoteWeights[3] = addingWeights[0];

    _assertBridgeMembers({
      comparingOperators: beforeBridgeOperators,
      comparingGovernors: beforeGovernors,
      comparingWeights: beforeVoteWeights,
      expectingOperators: afterBridgeOperators,
      expectingGovernors: afterGovernors,
      expectingWeights: afterVoteWeights
    });
    assertEq(_bridgeManager.getTotalWeight(), _totalWeight);
  }
}
