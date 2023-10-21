// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17 <0.9.0;

import { Base_Test } from "@ronin/test/Base.t.sol";

import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { MockBridgeManager } from "@ronin/contracts/mocks/ronin/MockBridgeManager.sol";

contract BridgeManager_Unit_Concrete_Test is Base_Test {
  IBridgeManager internal _bridgeManager;
  address[] internal _bridgeOperators;
  address[] internal _governors;
  uint96[] internal _voteWeights;
  uint256 internal _totalWeight;
  uint256 internal _totalOperator;

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

    _assertBridgeMembers({
      comparingOperators: beforeBridgeOperators,
      expectingOperators: afterBridgeOperators,
      comparingGovernors: beforeGovernors,
      expectingGovernors: afterGovernors,
      comparingWeights: beforeVoteWeights,
      expectingWeights: afterVoteWeights
    });
    assertEq(_bridgeManager.getTotalWeight(), _totalWeight);
  }

  function setUp() public virtual {
    address[] memory bridgeOperators = new address[](3);
    bridgeOperators[0] = address(0x10000);
    bridgeOperators[1] = address(0x10001);
    bridgeOperators[2] = address(0x10002);

    address[] memory governors = new address[](3);
    governors[0] = address(0x20000);
    governors[1] = address(0x20001);
    governors[2] = address(0x20002);

    uint96[] memory voteWeights = new uint96[](3);
    voteWeights[0] = 100;
    voteWeights[1] = 100;
    voteWeights[2] = 100;

    for (uint i; i < bridgeOperators.length; i++) {
      _bridgeOperators.push(bridgeOperators[i]);
      _governors.push(governors[i]);
      _voteWeights.push(voteWeights[i]);
    }

    _totalWeight = 300;
    _totalOperator = 3;

    _bridgeManager = new MockBridgeManager(bridgeOperators, governors, voteWeights);
  }

  function _generateNewOperators()
    internal
    pure
    returns (address[] memory operators, address[] memory governors, uint96[] memory weights)
  {
    operators = new address[](1);
    operators[0] = address(0x10003);

    governors = new address[](1);
    governors[0] = address(0x20003);

    weights = new uint96[](1);
    weights[0] = 100;
  }

  function _generateRemovingOperators(
    uint removingNumber
  )
    internal
    view
    returns (
      address[] memory removingOperators,
      address[] memory removingGovernors,
      uint96[] memory removingWeights,
      address[] memory remainingOperators,
      address[] memory remainingGovernors,
      uint96[] memory remainingWeights
    )
  {
    if (removingNumber > _totalOperator) {
      revert();
    }

    uint remainingNumber = _totalOperator - removingNumber;

    removingOperators = new address[](removingNumber);
    removingGovernors = new address[](removingNumber);
    removingWeights = new uint96[](removingNumber);
    remainingOperators = new address[](remainingNumber);
    remainingGovernors = new address[](remainingNumber);
    remainingWeights = new uint96[](remainingNumber);

    for (uint i; i < removingNumber; i++) {
      removingOperators[i] = _bridgeOperators[i];
      removingGovernors[i] = _governors[i];
      removingWeights[i] = _voteWeights[i];
    }

    for (uint i = removingNumber; i < _totalOperator; i++) {
      remainingOperators[i - removingNumber] = _bridgeOperators[i];
      remainingGovernors[i - removingNumber] = _governors[i];
      remainingWeights[i - removingNumber] = _voteWeights[i];
    }
  }

  function _generateBridgeOperatorAddressToUpdate() internal pure returns (address) {
    return address(0x10010);
  }

  function _getBridgeMembers()
    internal
    view
    returns (address[] memory bridgeOperators, address[] memory governors, uint96[] memory voteWeights)
  {
    governors = _bridgeManager.getGovernors();
    bridgeOperators = _bridgeManager.getBridgeOperatorOf(governors);
    voteWeights = _bridgeManager.getGovernorWeights(governors);
    // (governors, bridgeOperators, voteWeights) = _bridgeManager.getFullBridgeOperatorInfos();
  }

  function _getBridgeMembers(
    address[] memory governors
  ) internal view returns (address[] memory bridgeOperators, address[] memory governors_, uint96[] memory voteWeights) {
    governors_ = governors;
    bridgeOperators = _bridgeManager.getBridgeOperatorOf(governors);
    voteWeights = _bridgeManager.getGovernorWeights(governors);
    // (governors, bridgeOperators, voteWeights) = _bridgeManager.getFullBridgeOperatorInfos();
  }

  function _assertBridgeMembers(
    address[] memory comparingOperators,
    address[] memory expectingOperators,
    address[] memory comparingGovernors,
    address[] memory expectingGovernors,
    uint96[] memory comparingWeights,
    uint96[] memory expectingWeights
  ) internal {
    assertEq(comparingOperators, expectingOperators, "wrong bridge operators");
    assertEq(comparingGovernors, expectingGovernors, "wrong governors");
    assertEq(comparingWeights, expectingWeights, "wrong weights");
  }
}
