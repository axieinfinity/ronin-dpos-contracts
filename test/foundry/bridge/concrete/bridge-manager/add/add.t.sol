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

  modifier assertStateNotChange() {
    // Get before test state
    (
      address[] memory beforeBridgeOperators,
      address[] memory beforeGovernors,
      uint96[] memory beforeVoteWeights
    ) = _getBridgeMembers();

    _;

    // Compare after and before state
    (
      address[] memory afterBridgeOperators,
      address[] memory afterGovernors,
      uint96[] memory afterVoteWeights
    ) = _getBridgeMembers();

    assertEq(beforeBridgeOperators, afterBridgeOperators, "wrong BridgeOperators");
    assertEq(beforeGovernors, afterGovernors, "wrong Governors");
    assertEq(beforeVoteWeights, afterVoteWeights, "wrong VoteWeights");
  }

  function test_RevertWhen_NotSelfCall() external {
    // Prepare data
    (
      address[] memory bridgeOperators,
      address[] memory governors,
      uint96[] memory voteWeights
    ) = _generateNewOperators();

    // Make the caller not self-call.
    changePrank({ msgSender: _bridgeOperators[0] });

    // Run the test.
    vm.expectRevert(abi.encodeWithSelector(ErrOnlySelfCall.selector, IBridgeManager.addBridgeOperators.selector));
    _bridgeManager.addBridgeOperators(voteWeights, governors, bridgeOperators);
  }

  function test_RevertWhen_ThreeInputArrayLengthMismatch() external {
    // Prepare data
    (
      address[] memory bridgeOperators,
      address[] memory governors,
      uint96[] memory voteWeights
    ) = _generateNewOperators();

    uint length = bridgeOperators.length;

    assembly {
      mstore(bridgeOperators, add(length, 1))
    }
    vm.expectRevert(abi.encodeWithSelector(ErrLengthMismatch.selector, IBridgeManager.addBridgeOperators.selector));
    _bridgeManager.addBridgeOperators(voteWeights, governors, bridgeOperators);

    assembly {
      mstore(bridgeOperators, length)
      mstore(governors, add(length, 1))
    }
    vm.expectRevert(abi.encodeWithSelector(ErrLengthMismatch.selector, IBridgeManager.addBridgeOperators.selector));
    _bridgeManager.addBridgeOperators(voteWeights, governors, bridgeOperators);

    assembly {
      mstore(governors, length)
      mstore(voteWeights, add(length, 1))
    }
    vm.expectRevert(abi.encodeWithSelector(ErrLengthMismatch.selector, IBridgeManager.addBridgeOperators.selector));
    _bridgeManager.addBridgeOperators(voteWeights, governors, bridgeOperators);
  }

  function test_RevertWhen_VoteWeightIsZero() external {
    // Prepare data
    (
      address[] memory bridgeOperators,
      address[] memory governors,
      uint96[] memory voteWeights
    ) = _generateNewOperators();

    voteWeights[0] = 0;
    vm.expectRevert(abi.encodeWithSelector(ErrInvalidVoteWeight.selector, IBridgeManager.addBridgeOperators.selector));
    _bridgeManager.addBridgeOperators(voteWeights, governors, bridgeOperators);
  }

  function test_RevertWhen_BridgeOperatorAddressIsZero() external {
    // Prepare data
    (
      address[] memory bridgeOperators,
      address[] memory governors,
      uint96[] memory voteWeights
    ) = _generateNewOperators();

    bridgeOperators[0] = address(0);
    vm.expectRevert(abi.encodeWithSelector(ErrZeroAddress.selector, IBridgeManager.addBridgeOperators.selector));
    _bridgeManager.addBridgeOperators(voteWeights, governors, bridgeOperators);
  }

  function test_RevertWhen_GovernorAddressIsZero() external {
    // Prepare data
    (
      address[] memory bridgeOperators,
      address[] memory governors,
      uint96[] memory voteWeights
    ) = _generateNewOperators();

    governors[0] = address(0);
    vm.expectRevert(abi.encodeWithSelector(ErrZeroAddress.selector, IBridgeManager.addBridgeOperators.selector));
    _bridgeManager.addBridgeOperators(voteWeights, governors, bridgeOperators);
  }

  function test_AddOperators_DuplicatedGovernor() external assertStateNotChange {
    (
      address[] memory bridgeOperators,
      address[] memory governors,
      uint96[] memory voteWeights
    ) = _generateNewOperators();

    governors[0] = _governors[0];
    bool[] memory addeds = _bridgeManager.addBridgeOperators(voteWeights, governors, bridgeOperators);
    bool[] memory expectedAddeds = new bool[](1);
    expectedAddeds[0] = false;
    assertEq(addeds, expectedAddeds);
  }

  function test_AddOperators_DuplicatedBridgeOperator() external assertStateNotChange {
    (
      address[] memory bridgeOperators,
      address[] memory governors,
      uint96[] memory voteWeights
    ) = _generateNewOperators();

    bridgeOperators[0] = _bridgeOperators[0];
    bool[] memory addeds = _bridgeManager.addBridgeOperators(voteWeights, governors, bridgeOperators);
    bool[] memory expectedAddeds = new bool[](1);
    expectedAddeds[0] = false;
    assertEq(addeds, expectedAddeds);
  }

  function test_AddOperators_DuplicatedGovernorWithExistedBridgeOperator() external assertStateNotChange {
    (
      address[] memory bridgeOperators,
      address[] memory governors,
      uint96[] memory voteWeights
    ) = _generateNewOperators();

    governors[0] = _bridgeOperators[0];
    bool[] memory addeds = _bridgeManager.addBridgeOperators(voteWeights, governors, bridgeOperators);
    bool[] memory expectedAddeds = new bool[](1);
    expectedAddeds[0] = false;
    assertEq(addeds, expectedAddeds);
  }

  function test_AddOperators_DuplicatedBridgeOperatorWithExistedGovernor() external assertStateNotChange {
    (
      address[] memory bridgeOperators,
      address[] memory governors,
      uint96[] memory voteWeights
    ) = _generateNewOperators();

    bridgeOperators[0] = _governors[0];
    bool[] memory addeds = _bridgeManager.addBridgeOperators(voteWeights, governors, bridgeOperators);
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
      address[] memory bridgeOperators,
      address[] memory governors,
      uint96[] memory voteWeights
    ) = _generateNewOperators();

    bool[] memory addeds = _bridgeManager.addBridgeOperators(voteWeights, governors, bridgeOperators);
    bool[] memory expectedAddeds = new bool[](1);
    expectedAddeds[0] = true;
    assertEq(addeds, expectedAddeds);

    // Compare after and before state
    (
      address[] memory afterBridgeOperators,
      address[] memory afterGovernors,
      uint96[] memory afterVoteWeights
    ) = _getBridgeMembers();

    uint extendedLength = beforeBridgeOperators.length + 1;
    assembly {
      mstore(beforeBridgeOperators, extendedLength)
      mstore(beforeGovernors, extendedLength)
      mstore(beforeVoteWeights, extendedLength)
    }

    beforeBridgeOperators[3] = bridgeOperators[0];
    beforeGovernors[3] = governors[0];
    beforeVoteWeights[3] = voteWeights[0];

    assertEq(beforeBridgeOperators, afterBridgeOperators, "wrong BridgeOperators");
    assertEq(beforeGovernors, afterGovernors, "wrong Governors");
    assertEq(beforeVoteWeights, afterVoteWeights, "wrong VoteWeights");
  }

  function _generateNewOperators()
    internal
    pure
    returns (address[] memory bridgeOperators, address[] memory governors, uint96[] memory voteWeights)
  {
    bridgeOperators = new address[](1);
    bridgeOperators[0] = address(0x10003);

    governors = new address[](1);
    governors[0] = address(0x20003);

    voteWeights = new uint96[](1);
    voteWeights[0] = 100;
  }
}
