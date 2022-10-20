// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./MockPrecompile.sol";
import "../libraries/Sorting.sol";
import "../libraries/EnumFlags.sol";
import "../ronin/validator/RoninValidatorSet.sol";

contract MockRoninValidatorSetExtended is RoninValidatorSet, MockPrecompile {
  uint256[] internal _epochs;
  uint256[] internal _periods;

  constructor() {}

  function endEpoch() external {
    _epochs.push(block.number);
  }

  function endPeriod() external {
    _periods.push(block.number);
  }

  function periodOf(uint256 _block) public view override returns (uint256 _period) {
    for (uint256 _i = _periods.length; _i > 0; _i--) {
      if (_block >= _periods[_i - 1]) {
        return _i;
      }
    }
  }

  function epochOf(uint256 _block) public view override returns (uint256 _epoch) {
    for (uint256 _i = _epochs.length; _i > 0; _i--) {
      if (_block >= _epochs[_i - 1]) {
        return _i;
      }
    }
  }

  function epochEndingAt(uint256 _block) public view override returns (bool) {
    for (uint _i = 0; _i < _epochs.length; _i++) {
      if (_block == _epochs[_i]) {
        return true;
      }
    }
    return false;
  }

  function periodEndingAt(uint256 _block) public view override returns (bool) {
    for (uint _i = 0; _i < _periods.length; _i++) {
      if (_block == _periods[_i]) {
        return true;
      }
    }
    return false;
  }

  function getJailUntils(address[] calldata _addrs) public view returns (uint256[] memory jailUntils_) {
    jailUntils_ = new uint256[](_addrs.length);
    for (uint _i = 0; _i < _addrs.length; _i++) {
      jailUntils_[_i] = _jailedUntil[_addrs[_i]];
    }
  }

  function addValidators(address[] calldata _addrs) public {
    for (uint _i = 0; _i < _addrs.length; _i++) {
      _validators[_i] = _addrs[_i];
      _validatorMap[_addrs[_i]] = EnumFlags.ValidatorFlag.Both;
    }
  }

  function arrangeValidatorCandidates(
    address[] memory _candidates,
    uint256[] memory _trustedWeights,
    uint _newValidatorCount,
    uint _maxPrioritizedValidatorNumber
  ) external pure returns (address[] memory) {
    _arrangeValidatorCandidates(_candidates, _trustedWeights, _newValidatorCount, _maxPrioritizedValidatorNumber);

    assembly {
      mstore(_candidates, _newValidatorCount)
    }

    return _candidates;
  }

  function _pcSortCandidates(address[] memory _candidates, uint256[] memory _weights)
    internal
    pure
    override
    returns (address[] memory _result)
  {
    return Sorting.sort(_candidates, _weights);
  }

  function _pcPickValidatorSet(
    address[] memory _candidates,
    uint256[] memory _balanceWeights,
    uint256[] memory _trustedWeights,
    uint256 _maxValidatorNumber,
    uint256 _maxPrioritizedValidatorNumber
  ) internal pure override returns (address[] memory _result, uint256 _newValidatorCount) {
    _result = pickValidatorSet(
      _candidates,
      _balanceWeights,
      _trustedWeights,
      _maxValidatorNumber,
      _maxPrioritizedValidatorNumber
    );

    _newValidatorCount = _result.length;
  }
}
