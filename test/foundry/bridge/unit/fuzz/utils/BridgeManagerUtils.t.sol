// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { Randomizer } from "@ronin/test/helpers/Randomizer.t.sol";
import { Sorting } from "@ronin/contracts/mocks/libraries/Sorting.sol";
import { AddressArrayUtils } from "@ronin/contracts/libraries/AddressArrayUtils.sol";
import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { IBridgeManagerEvents } from "@ronin/contracts/interfaces/bridge/events/IBridgeManagerEvents.sol";

abstract contract BridgeManagerUtils is Randomizer {
  using Sorting for uint256[];
  using AddressArrayUtils for address[];

  uint256 internal constant DEFAULT_R1 = 1;
  uint256 internal constant DEFAULT_R2 = 2;
  uint256 internal constant DEFAULT_R3 = 3;
  uint256 internal constant DEFAULT_NUM_BRIDGE_OPERATORS = 5;

  uint256 internal constant MIN_AMOUNT = 1;
  uint256 internal constant MIN_FUZZ_INPUTS = 1;
  uint256 internal constant MAX_FUZZ_INPUTS = 100;
  uint256 internal constant MIN_VOTE_WEIGHT = 1;
  uint256 internal constant MAX_VOTE_WEIGHT = type(uint96).max;

  function _addBridgeOperators(
    address caller,
    address bridgeManagerContract,
    uint96[] memory voteWeights,
    address[] memory governors,
    address[] memory bridgeOperators
  ) internal virtual returns (IBridgeManager bridgeManager) {
    vm.expectEmit(bridgeManagerContract);
    bool[] memory statuses;
    uint256[] memory tmp = _createRandomNumbers(0, voteWeights.length, 1, 1);
    assembly {
      statuses := tmp
    }
    emit BridgeOperatorsAdded(statuses, voteWeights, governors, bridgeOperators);
    bridgeManager = IBridgeManager(bridgeManagerContract);
    vm.prank(caller);
    bridgeManager.addBridgeOperators(voteWeights, governors, bridgeOperators);
  }

  function getValidInputs(
    uint256 r1,
    uint256 r2,
    uint256 r3,
    uint256 numBridgeOperators
  ) public virtual returns (address[] memory bridgeOperators, address[] memory governors, uint96[] memory voteWeights) {
    // ensure r1, r2, r3 is unique
    vm.assume(!(r1 == r2 || r2 == r3 || r1 == r3));
    numBridgeOperators = _bound(numBridgeOperators, MIN_FUZZ_INPUTS, MAX_FUZZ_INPUTS);

    governors = _createRandomAddresses(r1, numBridgeOperators);
    bridgeOperators = _createRandomAddresses(r2, numBridgeOperators);
    uint256[] memory _voteWeights = _createRandomNumbers(r3, numBridgeOperators, MIN_VOTE_WEIGHT, MAX_VOTE_WEIGHT);
    assembly {
      voteWeights := _voteWeights
    }

    _ensureValidAddBridgeOperatorsInputs(voteWeights, governors, bridgeOperators);
  }

  function _nullOrDuplicateInputs(
    uint256 r1,
    uint256 r2,
    uint256 r3,
    uint256 numBridgeOperators
  )
    internal
    virtual
    returns (
      bool nullifyOrDuplicate, // true is nullify, false is duplicate
      uint256 modifyTimes,
      uint256 modifiedInputIdx,
      uint96[] memory voteWeights,
      address[] memory governors,
      address[] memory bridgeOperators
    )
  {
    (bridgeOperators, governors, voteWeights) = getValidInputs(r1, r2, r3, numBridgeOperators);
    uint256[] memory uintGovernors;
    uint256[] memory uintBridgeOperators;
    uint256[] memory uintVoteWeights;
    assembly {
      uintGovernors := governors
      uintVoteWeights := voteWeights
      uintBridgeOperators := bridgeOperators
    }

    uint256[] memory outputs;
    // get rid of stack too deep
    {
      uint256 seed = _triShuffle(r1, r2, r3);
      nullifyOrDuplicate = seed % 2 == 0;
      modifiedInputIdx = _randomize({ seed: seed, min: 0, max: 2 });
      modifyTimes = _randomize({ seed: modifiedInputIdx, min: MIN_AMOUNT, max: numBridgeOperators });

      (, bytes memory returnData) = address(this).staticcall(
        abi.encodeWithSelector(
          nullifyOrDuplicate ? this.nullifyInputs.selector : this.duplicateInputs.selector,
          seed,
          modifyTimes,
          // 0 = modify voteWeights, 1 = modify governors, 2 = modify bridge operators
          modifiedInputIdx == 0 ? uintVoteWeights : modifiedInputIdx == 1 ? uintGovernors : uintBridgeOperators
        )
      );
      (outputs, ) = abi.decode(returnData, (uint256[], uint256[]));
    }

    // point outputs to modified inputs
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
  ) public pure virtual returns (uint256[] memory outputs, uint256[] memory dupplicateIndices) {
    uint256 inputLength = inputs.length;
    vm.assume(inputLength != 0);
    duplicateAmount = _bound(duplicateAmount, 1, inputLength);

    uint256 r1;
    uint256 r2;
    dupplicateIndices = new uint256[](duplicateAmount);

    // bound index to range [0, inputLength - 1]
    inputLength--;

    for (uint256 i; i < duplicateAmount; ) {
      r1 = _randomize(seed, 0, inputLength);
      r2 = _randomize(r1, 0, inputLength);
      vm.assume(r1 != r2);
      // save dupplicate index
      dupplicateIndices[i] = r1;

      // copy inputs[r2] to inputs[r1]
      inputs[r1] = inputs[r2];
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
  ) public pure virtual returns (uint256[] memory outputs, uint256[] memory nullifyIndices) {
    uint256 inputLength = inputs.length;
    vm.assume(inputLength != 0);
    nullAmount = _bound(nullAmount, 1, inputLength);

    // bound index to range [0, inputLength - 1]
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
    uint96[] memory voteWeights,
    address[] memory governors,
    address[] memory bridgeOperators
  ) internal pure virtual {
    vm.assume(voteWeights.length == governors.length && governors.length == bridgeOperators.length);

    uint256[] memory uintGovernors;
    uint256[] memory uintVoteWeights;
    uint256[] memory uintBridgeOperators;
    // cast address[] to uint256[]
    assembly {
      uintGovernors := governors
      uintVoteWeights := voteWeights
      uintBridgeOperators := bridgeOperators
    }
    _ensureNonZero(uintVoteWeights);
    _ensureNonZero(uintGovernors);
    _ensureNonZero(uintBridgeOperators);

    _ensureNonDuplicated(governors.extend(bridgeOperators));
  }

  function _sort(address[] memory inputs) internal pure returns (address[] memory outputs) {
    uint256[] memory uintInputs;
    assembly {
      uintInputs := inputs
    }
    uint256[] memory uintOutputs = uintInputs.sort();
    assembly {
      outputs := uintOutputs
    }
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

  function _triShuffle(uint256 a, uint256 b, uint256 c) internal pure returns (uint256) {
    return a ^ b ^ c;
  }

  function _ensureNonDuplicated(address[] memory addrs) internal pure {
    vm.assume(!addrs.hasDuplicate());
  }

  function _invariantTest(
    IBridgeManager bridgeManager,
    uint96[] memory voteWeights,
    address[] memory governors,
    address[] memory bridgeOperators
  ) internal virtual {
    assertEq(governors, bridgeManager.getGovernors());
    assertEq(bridgeOperators, bridgeManager.getBridgeOperators());
    assertEq(voteWeights, bridgeManager.getGovernorWeights(governors));
    assertEq(bridgeOperators.length, bridgeManager.totalBridgeOperator());
    // assertEq(_sort(bridgeOperators), _sort(bridgeManager.getBridgeOperatorOf(governors)));

    uint256 totalWeight;
    for (uint256 i; i < voteWeights.length; ) {
      totalWeight += voteWeights[i];
      unchecked {
        ++i;
      }
    }

    assertEq(totalWeight, bridgeManager.getTotalWeight());
  }
}
