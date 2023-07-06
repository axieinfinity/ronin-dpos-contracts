// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Vm, Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { RoninGatewayV2 } from "@ronin/contracts/ronin/gateway/RoninGatewayV2.sol";
import { RoleAccess, ContractType, AddressArrayUtils, IBridgeManager, MockBridgeManager } from "@ronin/contracts/mocks/ronin/MockBridgeManager.sol";
import { ErrUnauthorized, ErrInvalidVoteWeight, ErrZeroAddress, ErrUnexpectedInternalCall } from "@ronin/contracts/utils/CommonErrors.sol";

contract BridgeManagerTest is Test {
  using AddressArrayUtils for address[];

  enum InputIndex {
    VoteWeights,
    Governors,
    BridgeOperators
  }

  event BridgeOperatorsAdded(bool[] statuses, uint256[] voteWeights, address[] governors, address[] bridgeOperators);

  event BridgeOperatorsRemoved(bool[] statuses, address[] bridgeOperators);

  event BridgeOperatorUpdated(
    address indexed operator,
    address indexed fromBridgeOperator,
    address indexed toBridgeOperator
  );

  uint256 private constant MAX_FUZZ_INPUTS = 100;

  address private _bridgeManager;
  address private _bridgeContract;

  function setUp() external {
    _setUp();
    _label();
  }

  /**
   * @notice Checks whether unauthorized caller except bridge contract can add bridge operators.
   */
  function testFail_AddBridgeOperators_CallerNotBridgeAdminOperator(
    address caller,
    uint256 r1,
    uint256 r2,
    uint256 r3,
    uint256 numBridgeOperators
  ) external {
    vm.assume(caller != _bridgeManager);

    (uint256[] memory voteWeights, address[] memory governors, address[] memory bridgeOperators) = _getValidInputs(
      r1,
      r2,
      r3,
      numBridgeOperators
    );

    vm.expectRevert(
      abi.encodeWithSelector(
        ErrUnexpectedInternalCall.selector,
        IBridgeManager.addBridgeOperators.selector,
        ContractType.BRIDGE,
        caller
      )
    );

    _addBridgeOperators(caller, voteWeights, governors, bridgeOperators);
  }

  /**
   * @notice Checks whether bridge contract can add bridge operators.
   */
  function test_AddBridgeOperators_CallerIsBridgeAdminOperator(
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

    IBridgeManager bridgeManager = _addBridgeOperators(_bridgeManager, voteWeights, governors, bridgeOperators);

    _invariantTest(bridgeManager, voteWeights, governors, bridgeOperators);
  }

  /**
   * @notice Checks whether bridge contract can add bridge operators
   * when governors, operators or vote weight contains null or duplicated.
   */
  function testFail_AddBridgeOperators_NullOrDuplicateInputs(
    uint256 r1,
    uint256 r2,
    uint256 r3,
    uint256 numBridgeOperators
  ) external {
    (
      bool nullifyOrDuplicate,
      uint256 modifyTimes,
      uint256 modifiedInputIdx,
      uint256[] memory voteWeights,
      address[] memory governors,
      address[] memory bridgeOperators
    ) = _nullOrDuplicateInputs(r1, r2, r3, numBridgeOperators);

    if (modifiedInputIdx == uint8(InputIndex.VoteWeights)) {
      // allow duplicate vote weights
      vm.assume(nullifyOrDuplicate);
      vm.expectRevert(
        abi.encodeWithSelector(ErrInvalidVoteWeight.selector, IBridgeManager.addBridgeOperators.selector)
      );
    } else {
      if (modifyTimes == 1) {
        vm.expectRevert(abi.encodeWithSelector(ErrZeroAddress.selector, IBridgeManager.addBridgeOperators.selector));
      } else {
        vm.expectRevert(
          abi.encodeWithSelector(AddressArrayUtils.ErrDuplicated.selector, IBridgeManager.addBridgeOperators.selector)
        );
      }
    }

    _addBridgeOperators(_bridgeManager, voteWeights, governors, bridgeOperators);
  }

  /**
   * @notice Checks whether bridge contract can remove bridge operators.
   */
  function test_RemoveBridgeOperators_CallerIsBridgeContract(
    uint256 r1,
    uint256 r2,
    uint256 r3,
    uint16 numBridgeOperators
  ) external {
    (uint256[] memory voteWeights, address[] memory governors, address[] memory bridgeOperators) = _getValidInputs(
      r1,
      r2,
      r3,
      numBridgeOperators
    );

    IBridgeManager bridgeManager = _addBridgeOperators(_bridgeManager, voteWeights, governors, bridgeOperators);
    uint256 removeAmount = _randomize(voteWeights.length, 1, voteWeights.length);

    uint256 tailIdx = voteWeights.length - 1;
    uint256 r = _randomize(r1 ^ r2 ^ r3, 0, tailIdx);
    address[] memory removeBridgeOperators = new address[](removeAmount);
    for (uint256 i; i < removeAmount; ) {
      r = _randomize(r, 0, tailIdx);

      governors[r] = governors[tailIdx];
      voteWeights[r] = voteWeights[tailIdx];
      removeBridgeOperators[i] = bridgeOperators[r];
      bridgeOperators[r] = bridgeOperators[tailIdx];

      unchecked {
        ++i;
        --tailIdx;
      }
    }

    uint256 remainLength = voteWeights.length - removeAmount;
    assembly {
      mstore(governors, remainLength)
      mstore(voteWeights, remainLength)
      mstore(bridgeOperators, remainLength)
    }

    vm.prank(_bridgeManager);
    vm.expectEmit(_bridgeManager);
    bool[] memory statuses;
    uint256[] memory tmp = _createRandomNumbers(0, removeBridgeOperators.length, 1, 1);
    assembly {
      statuses := tmp
    }
    emit BridgeOperatorsRemoved(statuses, removeBridgeOperators);
    bridgeManager.removeBridgeOperators(removeBridgeOperators);

    _invariantTest(bridgeManager, voteWeights, governors, bridgeOperators);
  }

  /**
   * @notice Checks whether governor can update their bridge operator address.
   */
  function test_UpdateBridgeOperator_CallerIsGovernor(
    uint256 r1,
    uint256 r2,
    uint256 r3,
    uint16 numBridgeOperators
  ) external {
    (uint256[] memory voteWeights, address[] memory governors, address[] memory bridgeOperators) = _getValidInputs(
      r1,
      r2,
      r3,
      numBridgeOperators
    );
    IBridgeManager bridgeManager = _addBridgeOperators(_bridgeManager, voteWeights, governors, bridgeOperators);

    uint256 randomSeed = _randomize(r1 ^ r2 ^ r3, 0, voteWeights.length - 1);
    address randomGovernor = governors[randomSeed];
    address newBridgeOperator = makeAddr("NEW_BRIDGE_OPERATOR");

    vm.prank(randomGovernor);
    vm.expectEmit(_bridgeManager);
    bool[] memory statuses = new bool[](1);
    statuses[0] = true;
    emit BridgeOperatorUpdated(randomGovernor, bridgeOperators[randomSeed], newBridgeOperator);
    bridgeManager.updateBridgeOperator(newBridgeOperator);

    // swap and pop
    bridgeOperators[randomSeed] = bridgeOperators[bridgeOperators.length - 1];
    bridgeOperators[bridgeOperators.length - 1] = newBridgeOperator;

    _invariantTest(bridgeManager, voteWeights, governors, bridgeOperators);
  }

  /**
   * @notice Checks whether unauthorized sender can update bridge operator address.
   */
  function testFail_UpdateBridgeOperator_CallerIsNotGovernor(
    uint256 r1,
    uint256 r2,
    uint256 r3,
    uint16 numBridgeOperators
  ) external {
    (uint256[] memory voteWeights, address[] memory governors, address[] memory bridgeOperators) = _getValidInputs(
      r1,
      r2,
      r3,
      numBridgeOperators
    );
    IBridgeManager bridgeManager = _addBridgeOperators(_bridgeManager, voteWeights, governors, bridgeOperators);

    address unauthorizedCaller = makeAddr("UNAUTHORIZED_CALLER");
    for (uint256 i; i < governors.length; ) {
      vm.assume(unauthorizedCaller != governors[i]);
      unchecked {
        ++i;
      }
    }
    address newBridgeOperator = makeAddr("NEW_BRIDGE_OPERATOR");

    vm.prank(unauthorizedCaller);
    bridgeManager.updateBridgeOperator(newBridgeOperator);

    vm.expectRevert(
      abi.encodeWithSelector(
        ErrUnauthorized.selector,
        IBridgeManager.updateBridgeOperator.selector,
        RoleAccess.GOVERNOR
      )
    );
  }

  function _setUp() internal virtual {
    _bridgeContract = address(new RoninGatewayV2());
    (uint256[] memory voteWeights, address[] memory governors, address[] memory bridgeOperators) = _getValidInputs(
      1,
      2,
      3,
      5
    );
    _bridgeManager = address(new MockBridgeManager(_bridgeContract, voteWeights, governors, bridgeOperators));

    // empty storage for testing
    vm.prank(_bridgeManager);
    IBridgeManager(_bridgeManager).removeBridgeOperators(bridgeOperators);
  }

  function _label() internal virtual {
    vm.label(_bridgeContract, "BRIDGE_CONTRACT");
    vm.label(_bridgeManager, "BRIDGE_ADMIN_OPERATOR");
  }

  function _invariantTest(
    IBridgeManager bridgeManager,
    uint256[] memory voteWeights,
    address[] memory governors,
    address[] memory bridgeOperators
  ) internal {
    assertEq(governors, bridgeManager.getGovernors());
    assertEq(bridgeOperators, bridgeManager.getBridgeOperators());
    assertEq(voteWeights, bridgeManager.getBridgeVoterWeights(governors));
    assertEq(bridgeOperators.length, bridgeManager.totalBridgeOperators());
    // assertEq(bridgeOperators, bridgeManager.getBridgeOperatorOf(governors));

    uint256 totalWeight;
    for (uint256 i; i < voteWeights.length; ) {
      totalWeight += voteWeights[i];
      unchecked {
        ++i;
      }
    }

    assertEq(totalWeight, bridgeManager.getTotalWeights());
  }

  function _addBridgeOperators(
    address caller,
    uint256[] memory voteWeights,
    address[] memory governors,
    address[] memory bridgeOperators
  ) internal returns (IBridgeManager bridgeManager) {
    vm.expectEmit(_bridgeManager);
    bool[] memory statuses;
    uint256[] memory tmp = _createRandomNumbers(0, voteWeights.length, 1, 1);
    assembly {
      statuses := tmp
    }
    emit BridgeOperatorsAdded(statuses, voteWeights, governors, bridgeOperators);
    bridgeManager = IBridgeManager(_bridgeManager);
    vm.prank(caller);
    bridgeManager.addBridgeOperators(voteWeights, governors, bridgeOperators);
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

  function _nullOrDuplicateInputs(
    uint256 r1,
    uint256 r2,
    uint256 r3,
    uint256 numBridgeOperators
  )
    internal
    view
    returns (
      bool nullifyOrDuplicate, // true is nullify, false is duplicate
      uint256 modifyTimes,
      uint256 modifiedInputIdx,
      uint256[] memory voteWeights,
      address[] memory governors,
      address[] memory bridgeOperators
    )
  {
    (voteWeights, governors, bridgeOperators) = _getValidInputs(r1, r2, r3, numBridgeOperators);
    uint256[] memory uintGovernors;
    uint256[] memory uintBridgeOperators;
    assembly {
      uintGovernors := governors
      uintBridgeOperators := bridgeOperators
    }

    uint256[] memory outputs;
    {
      uint256 seed = r1 ^ r2 ^ r3;
      nullifyOrDuplicate = seed % 2 == 0;
      modifiedInputIdx = _randomize({ seed: seed, min: 0, max: 2 });
      modifyTimes = _randomize({ seed: modifiedInputIdx, min: 1, max: numBridgeOperators });

      (, bytes memory returnData) = address(this).staticcall(
        abi.encodeWithSelector(
          nullifyOrDuplicate ? this.nullifyInputs.selector : this.duplicateInputs.selector,
          seed,
          modifyTimes,
          modifiedInputIdx == 0 ? voteWeights : modifiedInputIdx == 1 ? uintGovernors : uintBridgeOperators
        )
      );
      (outputs, ) = abi.decode(returnData, (uint256[], uint256[]));
    }

    assembly {
      if iszero(modifiedInputIdx) {
        voteWeights := outputs
      }
      if eq(modifiedInputIdx, 1) {
        governors := outputs
      }
      if eq(modifiedInputIdx, 2) {
        bridgeOperators := outputs
      }
    }
  }

  function duplicateInputs(
    uint256 seed,
    uint256 duplicateAmount,
    uint256[] memory inputs
  ) public pure returns (uint256[] memory outputs, uint256[] memory dupplicateIndices) {
    uint256 inputLength = inputs.length;
    vm.assume(inputLength != 0);
    duplicateAmount = _bound(duplicateAmount, 1, inputLength);

    inputLength--;

    uint256 r1;
    uint256 r2;
    dupplicateIndices = new uint256[](duplicateAmount);
    for (uint256 i; i < duplicateAmount; ) {
      r1 = _randomize(seed, 0, inputLength);
      r2 = _randomize(r1, 0, inputLength);
      vm.assume(r1 != r2);
      dupplicateIndices[i] = r1;

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

  function nullifyInputs(
    uint256 seed,
    uint256 nullAmount,
    uint256[] memory inputs
  ) public pure returns (uint256[] memory outputs, uint256[] memory nullifyIndices) {
    uint256 inputLength = inputs.length;
    vm.assume(inputLength != 0);
    nullAmount = _bound(nullAmount, 1, inputLength);

    inputLength--;

    uint256 r;
    nullifyIndices = new uint256[](nullAmount);
    for (uint256 i; i < nullAmount; ) {
      r = _randomize(seed, 0, inputLength);
      delete inputs[r];
      nullifyIndices[i] = r;
      seed = r;
      unchecked {
        ++i;
      }
    }
    address[] memory tmp;
    assembly {
      tmp := nullifyIndices
    }
    vm.assume(!AddressArrayUtils.hasDuplicate(tmp));
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
      seed = uint256(keccak256(abi.encode(seed)));
      addrs[i] = vm.addr(seed);
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
