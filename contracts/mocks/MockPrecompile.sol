// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./libraries/Sorting.sol";
import "../libraries/Math.sol";

contract MockPrecompile {
  function sortValidators(
    address[] memory _validators,
    uint256[] memory _weights
  ) public pure returns (address[] memory) {
    return Sorting.sort(_validators, _weights);
  }

  function validatingDoubleSignProof(
    address /*consensusAddr*/,
    bytes calldata /*_header1*/,
    bytes calldata /*_header2*/
  ) public pure returns (bool _validEvidence) {
    return true;
  }

  function validateFinalityVoteProof(
    bytes calldata,
    uint256,
    bytes32[2] calldata,
    bytes[][2] calldata,
    bytes[2] calldata
  ) public pure returns (bool) {
    return true;
  }

  function pickValidatorSet(
    address[] memory _candidates,
    uint256[] memory _weights,
    uint256[] memory _trustedWeights,
    uint256 _maxValidatorNumber,
    uint256 _maxPrioritizedValidatorNumber
  ) public pure returns (address[] memory _result) {
    (_result, _trustedWeights) = Sorting.sortWithExternalKeys(_candidates, _weights, _trustedWeights);
    uint256 _newValidatorCount = Math.min(_maxValidatorNumber, _result.length);
    _arrangeValidatorCandidates(_result, _trustedWeights, _newValidatorCount, _maxPrioritizedValidatorNumber);
  }

  /**
   * @dev Arranges the sorted candidates to list of validators, by asserting prioritized and non-prioritized candidates
   *
   * @param _candidates A sorted list of candidates
   */
  function _arrangeValidatorCandidates(
    address[] memory _candidates,
    uint256[] memory _trustedWeights,
    uint _newValidatorCount,
    uint _maxPrioritizedValidatorNumber
  ) internal pure {
    address[] memory _waitingCandidates = new address[](_candidates.length);
    uint _waitingCounter;
    uint _prioritySlotCounter;

    for (uint _i = 0; _i < _candidates.length; _i++) {
      if (_trustedWeights[_i] > 0 && _prioritySlotCounter < _maxPrioritizedValidatorNumber) {
        _candidates[_prioritySlotCounter++] = _candidates[_i];
        continue;
      }
      _waitingCandidates[_waitingCounter++] = _candidates[_i];
    }

    _waitingCounter = 0;
    for (uint _i = _prioritySlotCounter; _i < _newValidatorCount; _i++) {
      _candidates[_i] = _waitingCandidates[_waitingCounter++];
    }

    assembly {
      mstore(_candidates, _newValidatorCount)
    }
  }
}
