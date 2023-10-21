// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";
import { IBridgeManager, BridgeManagerUtils } from "../utils/BridgeManagerUtils.t.sol";
import { RoninGatewayV3 } from "@ronin/contracts/ronin/gateway/RoninGatewayV3.sol";
import { RoleAccess, ContractType, AddressArrayUtils, MockBridgeManager } from "@ronin/contracts/mocks/ronin/MockBridgeManager.sol";
import { ErrBridgeOperatorUpdateFailed, ErrBridgeOperatorAlreadyExisted, ErrUnauthorized, ErrInvalidVoteWeight, ErrZeroAddress, ErrUnexpectedInternalCall } from "@ronin/contracts/utils/CommonErrors.sol";

contract BridgeManagerCRUDTest is BridgeManagerUtils {
  using AddressArrayUtils for address[];

  enum InputIndex {
    VoteWeights,
    Governors,
    BridgeOperators
  }

  address internal _bridgeManager;

  function setUp() external {
    _setUp();
    _label();
  }

  function testFail_MaliciousUpdateBridgeOperator() external {
    (address[] memory bridgeOperators, address[] memory governors, uint96[] memory voteWeights) = getValidInputs(
      DEFAULT_R1,
      DEFAULT_R2,
      DEFAULT_R3,
      DEFAULT_NUM_BRIDGE_OPERATORS
    );
    _bridgeManager = address(new MockBridgeManager(bridgeOperators, governors, voteWeights));
    MockBridgeManager bridgeManager = MockBridgeManager(_bridgeManager);

    vm.startPrank(governors[0]);
    address lastOperator;

    for (uint256 i = 1; i < bridgeOperators.length; ++i) {
      lastOperator = bridgeOperators[i];
      bridgeManager.updateBridgeOperator(lastOperator);
      vm.expectRevert(abi.encodeWithSelector(ErrBridgeOperatorUpdateFailed.selector, lastOperator));
    }

    vm.stopPrank();
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
  ) external virtual {
    vm.assume(caller != _bridgeManager);

    (address[] memory bridgeOperators, address[] memory governors, uint96[] memory voteWeights) = getValidInputs(
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

    _addBridgeOperators(caller, _bridgeManager, voteWeights, governors, bridgeOperators);
  }

  /**
   * @notice Checks whether bridge contract can add bridge operators.
   */
  function test_AddBridgeOperators_CallerIsBridgeAdminOperator(
    uint256 r1,
    uint256 r2,
    uint256 r3,
    uint256 numBridgeOperators
  ) external virtual {
    (address[] memory bridgeOperators, address[] memory governors, uint96[] memory voteWeights) = getValidInputs(
      r1,
      r2,
      r3,
      numBridgeOperators
    );

    IBridgeManager bridgeManager = _addBridgeOperators(
      _bridgeManager,
      _bridgeManager,
      voteWeights,
      governors,
      bridgeOperators
    );

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
  ) external virtual {
    (
      bool nullifyOrDuplicate,
      uint256 modifyTimes,
      uint256 modifiedInputIdx,
      uint96[] memory voteWeights,
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

    _addBridgeOperators(_bridgeManager, _bridgeManager, voteWeights, governors, bridgeOperators);
  }

  /**
   * @notice Checks whether bridge contract can remove bridge operators.
   */
  function test_RemoveBridgeOperators_CallerIsBridgeContract(
    uint256 r1,
    uint256 r2,
    uint256 r3,
    uint16 numBridgeOperators
  ) external virtual {
    (address[] memory bridgeOperators, address[] memory governors, uint96[] memory voteWeights) = getValidInputs(
      r1,
      r2,
      r3,
      numBridgeOperators
    );

    IBridgeManager bridgeManager = _addBridgeOperators(
      _bridgeManager,
      _bridgeManager,
      voteWeights,
      governors,
      bridgeOperators
    );
    uint256 removeAmount = _randomize(voteWeights.length, 1, voteWeights.length);

    uint256 tailIdx = voteWeights.length - 1;
    uint256 r = _randomize(_triShuffle(r1, r2, r3), 0, tailIdx);
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
  ) external virtual {
    (address[] memory bridgeOperators, address[] memory governors, uint96[] memory voteWeights) = getValidInputs(
      r1,
      r2,
      r3,
      numBridgeOperators
    );
    IBridgeManager bridgeManager = _addBridgeOperators(
      _bridgeManager,
      _bridgeManager,
      voteWeights,
      governors,
      bridgeOperators
    );

    uint256 randomSeed = _randomize(_triShuffle(r1, r2, r3), 0, voteWeights.length - 1);
    address randomGovernor = governors[randomSeed];
    address newBridgeOperator = makeAddr("NEW_BRIDGE_OPERATOR");
    vm.deal(newBridgeOperator, 1 ether);

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
  ) external virtual {
    (address[] memory bridgeOperators, address[] memory governors, uint96[] memory voteWeights) = getValidInputs(
      r1,
      r2,
      r3,
      numBridgeOperators
    );
    IBridgeManager bridgeManager = _addBridgeOperators(
      _bridgeManager,
      _bridgeManager,
      voteWeights,
      governors,
      bridgeOperators
    );

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
    (address[] memory bridgeOperators, address[] memory governors, uint96[] memory voteWeights) = getValidInputs(
      DEFAULT_R1,
      DEFAULT_R2,
      DEFAULT_R3,
      DEFAULT_NUM_BRIDGE_OPERATORS
    );
    _bridgeManager = address(new MockBridgeManager(bridgeOperators, governors, voteWeights));

    // empty storage for testing
    vm.prank(_bridgeManager);
    IBridgeManager(_bridgeManager).removeBridgeOperators(bridgeOperators);
  }

  function _label() internal virtual {
    vm.label(_bridgeManager, "BRIDGE_ADMIN_OPERATOR");
  }
}
