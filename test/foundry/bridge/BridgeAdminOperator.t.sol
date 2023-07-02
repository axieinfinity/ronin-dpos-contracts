// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Vm, Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { RoninGatewayV2 } from "@ronin/contracts/ronin/gateway/RoninGatewayV2.sol";
import { ContractType, AddressArrayUtils, IBridgeAdminOperator, MockBridgeAdminOperator } from "@ronin/contracts/mocks/ronin/MockBridgeAdminOperator.sol";
import { ErrUnexpectedInternalCall } from "@ronin/contracts/utils/CommonErrors.sol";

contract BridgeAdminOperatorTest is Test {
  using AddressArrayUtils for address[];

  /**
   * @dev Enum representing the actions that can be performed on bridge operators.
   * - Add: Add a bridge operator.
   * - Update: Update a bridge operator.
   * - Remove: Remove a bridge operator.
   */
  enum BridgeAction {
    Add,
    Update,
    Remove
  }

  /**
   * @dev Emitted when a bridge operator is modified.
   * @param operator The address of the bridge operator being modified.
   * @param action The action performed on the bridge operator.
   */
  event BridgeOperatorSetModified(address indexed operator, BridgeAction indexed action);

  uint256 constant MAX_FUZZ_INPUTS = 100;

  address _bridgeContract;
  address _bridgeAdminOperator;

  function setUp() external {
    _setUp();
    _label();
  }

  function _setUp() internal virtual {
    _bridgeContract = address(new RoninGatewayV2());
    _bridgeAdminOperator = address(new MockBridgeAdminOperator(_bridgeContract));
  }

  function _label() internal virtual {
    vm.label(_bridgeContract, "BRIDGE_CONTRACT");
    vm.label(_bridgeAdminOperator, "BRIDGE_ADMIN_OPERATOR");
  }

  function testFail_NotBridgeContract_addBridgeOperators(
    address caller,
    uint256 r1,
    uint256 r2,
    uint256 r3,
    uint256 numBridgeOperators
  ) external {
    vm.assume(caller != _bridgeContract);

    (uint256[] memory voteWeights, address[] memory governors, address[] memory bridgeOperators) = _getValidInputs(
      r1,
      r2,
      r3,
      numBridgeOperators
    );

    vm.prank(caller);
    IBridgeAdminOperator(_bridgeAdminOperator).addBridgeOperators(voteWeights, governors, bridgeOperators);

    vm.expectRevert(
      abi.encodeWithSelector(
        ErrUnexpectedInternalCall.selector,
        IBridgeAdminOperator.addBridgeOperators.selector,
        ContractType.BRIDGE,
        caller
      )
    );
  }

  function test_BridgeContract_addBridgeOperators(
    uint256 r1,
    uint256 r2,
    uint256 r3,
    uint256 numBridgeOperators
  ) external {
    (uint256[] memory voteWeights, address[] memory governors, address[] memory bridgeOperators) = _getValidInputs(
      r1,
      r2,
      r3,
      numBridgeOperators
    );

    vm.expectEmit(_bridgeAdminOperator);
    emit BridgeOperatorSetModified(_bridgeContract, BridgeAction.Add);

    IBridgeAdminOperator bridgeAdminOperator = IBridgeAdminOperator(_bridgeAdminOperator);
    vm.prank(_bridgeContract);
    bridgeAdminOperator.addBridgeOperators(voteWeights, governors, bridgeOperators);

    assertEq(governors, bridgeAdminOperator.getGovernors());
    assertEq(bridgeOperators, bridgeAdminOperator.getBridgeOperators());
    assertEq(voteWeights, bridgeAdminOperator.getBridgeVoterWeights(governors));
    assertEq(bridgeOperators.length, bridgeAdminOperator.totalBridgeOperators());
    assertEq(bridgeOperators, bridgeAdminOperator.getBridgeOperatorOf(governors));

    uint256 totalWeight;
    for (uint256 i; i < voteWeights.length; ) {
      totalWeight += voteWeights[i];
      unchecked {
        ++i;
      }
    }
    
    assertEq(totalWeight, bridgeAdminOperator.getTotalWeights());
  }

  function _getValidInputs(
    uint256 r1,
    uint256 r2,
    uint256 r3,
    uint256 numBridgeOperators
  ) internal pure returns (uint256[] memory voteWeights, address[] memory governors, address[] memory bridgeOperators) {
    vm.assume(r1 != r2 && r2 != r3 && r1 != r3);
    numBridgeOperators = _bound(numBridgeOperators, 1, MAX_FUZZ_INPUTS);

    governors = _createAddresses(r1, numBridgeOperators);
    bridgeOperators = _createAddresses(r2, numBridgeOperators);
    voteWeights = _createRandomNumbers(r3, numBridgeOperators, 1, type(uint96).max);

    _ensureValidAddBridgeOperatorsInputs(voteWeights, governors, bridgeOperators);
  }

  function _duplicateInputs(
    uint256 seed,
    uint256 duplicateAmount,
    uint256[] memory inputs
  ) internal pure returns (uint256[] memory outputs) {
    uint256 inputLength = inputs.length;
    vm.assume(inputLength != 0);
    duplicateAmount = _bound(duplicateAmount, 1, inputLength);

    inputLength--;

    uint256 r1;
    uint256 r2;
    for (uint256 i; i < duplicateAmount; ) {
      r1 = _randomize(seed, 0, inputLength);
      r2 = _randomize(r1, 0, inputLength);
      vm.assume(r1 != r2);

      (inputs[r1], inputs[r2]) = (inputs[r2], inputs[r1]);
      seed = r1 ^ r2;
      unchecked {
        ++i;
      }
    }
    assembly {
      outputs := inputs
    }
  }

  function _nullifyInputs(
    uint256 seed,
    uint256 nullAmount,
    uint256[] memory inputs
  ) internal pure returns (uint256[] memory outputs) {
    uint256 inputLength = inputs.length;
    vm.assume(inputLength != 0);
    nullAmount = _bound(nullAmount, 1, inputLength);

    inputLength--;

    uint256 r;
    for (uint256 i; i < nullAmount; ) {
      r = _randomize(seed, 0, inputLength);
      delete inputs[r];
      seed = r;
      unchecked {
        ++i;
      }
    }
    assembly {
      outputs := inputs
    }
  }

  function _ensureValidAddBridgeOperatorsInputs(
    uint256[] memory voteWeights,
    address[] memory governors,
    address[] memory bridgeOperators
  ) internal pure {
    vm.assume(voteWeights.length == governors.length && governors.length == bridgeOperators.length);

    _ensureNonZero(voteWeights);

    uint256[] memory uintGovernors;
    uint256[] memory uintBridgeOperators;
    assembly {
      uintGovernors := governors
      uintBridgeOperators := bridgeOperators
    }
    _ensureNonZero(uintGovernors);
    _ensureNonZero(uintBridgeOperators);

    _ensureNonDuplicated(governors);
    _ensureNonDuplicated(bridgeOperators);

    address[] memory concatenated = new address[](governors.length + bridgeOperators.length);
    uint256 i;
    for (; i < governors.length; ) {
      concatenated[i] = governors[i];
      unchecked {
        ++i;
      }
    }
    for (uint256 j; j < bridgeOperators.length; ) {
      concatenated[i] = bridgeOperators[j];
      unchecked {
        ++i;
        ++j;
      }
    }
    _ensureNonDuplicated(concatenated);
  }

  function _ensureNonZero(uint256[] memory arr) internal pure {
    uint256 length = arr.length;
    for (uint256 i; i < length; ) {
      vm.assume(arr[i] != 0);
      unchecked {
        ++i;
      }
    }
  }

  function _ensureNonDuplicated(address[] memory addrs) internal pure {
    vm.assume(!addrs.hasDuplicate());
  }

  function _randomize(uint256 seed, uint256 min, uint256 max) internal pure returns (uint256 r) {
    r = _bound(uint256(keccak256(abi.encode(seed))), min, max);
  }

  function _createAddresses(uint256 seed, uint256 amount) internal pure returns (address[] memory addrs) {
    addrs = new address[](amount);
    for (uint256 i; i < amount; ) {
      addrs[i] = address(ripemd160(abi.encode(seed)));
      seed = uint256(keccak256(abi.encode(seed)));
      unchecked {
        ++i;
      }
    }
  }

  function _createRandomNumbers(
    uint256 seed,
    uint256 amount,
    uint256 min,
    uint256 max
  ) internal pure returns (uint256[] memory nums) {
    nums = new uint256[](amount);
    uint256 r;
    for (uint256 i; i < amount; ) {
      r = _randomize(seed, min, max);
      nums[i] = r;
      seed = r;

      unchecked {
        ++i;
      }
    }
  }
}
