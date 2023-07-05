// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../MockPrecompile.sol";
import "../../ronin/validator/RoninValidatorSet.sol";

contract MockRoninValidatorSetOverridePrecompile is RoninValidatorSet, MockPrecompile {
  constructor() {}

  function arrangeValidatorCandidates(
    address[] memory _candidates,
    uint256[] memory _trustedWeights,
    uint _newValidatorCount,
    uint _maxPrioritizedValidatorNumber
  ) external pure returns (address[] memory) {
    _arrangeValidatorCandidates(_candidates, _trustedWeights, _newValidatorCount, _maxPrioritizedValidatorNumber);
    return _candidates;
  }

  function _pcSortCandidates(
    address[] memory _candidates,
    uint256[] memory _weights
  ) internal pure override returns (address[] memory _result) {
    return sortValidators(_candidates, _weights);
  }

  function _pcPickValidatorSet(
    address[] memory _candidates,
    uint256[] memory _weights,
    uint256[] memory _trustedWeights,
    uint256 _maxValidatorNumber,
    uint256 _maxPrioritizedValidatorNumber
  ) internal pure override returns (address[] memory _result, uint256 _newValidatorCount) {
    _result = pickValidatorSet(
      _candidates,
      _weights,
      _trustedWeights,
      _maxValidatorNumber,
      _maxPrioritizedValidatorNumber
    );

    _newValidatorCount = _result.length;
  }
}
