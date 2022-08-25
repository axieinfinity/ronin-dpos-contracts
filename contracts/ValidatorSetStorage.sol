// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "./interfaces/IValidatorSet.sol";
import "./interfaces/IStaking.sol";

/**
 * @title Set of validators in current epoch
 * @notice This contract maintains set of validator in the current epoch of Ronin network
 */
abstract contract ValidatorSetStorage is IValidatorSet {
  using EnumerableMap for EnumerableMap.AddressToUintMap;

  /// @dev Array of all validators. The element at 0-slot is reserved for unknown validator.
  Validator[] public validatorSet;
  /// @dev Map of array of all validator
  mapping(address => uint256) public validatorSetMap;
  /// @dev Enumerable map of indexes of the current validator set, e.g. the array [3, 4, 1] tells
  /// the sequence of validators to mine block in the next epoch will be at the 3-, 4- and 1-index,
  /// One can query the mining order of an arbitrary address by this enumerable map.
  EnumerableMap.AddressToUintMap internal currentValidatorIndexesMap;

  function _setValidatorAtMiningIndex(uint256 _miningIndex, IStaking.ValidatorCandidate memory _incomingValidator)
    internal
  {
    address _newValAddr = _incomingValidator.consensusAddr;
    uint256 _index = _setValidator(_incomingValidator, false);

    (address _oldValAddr, ) = currentValidatorIndexesMap.at(_miningIndex);
    if (_oldValAddr != _newValAddr) {
      currentValidatorIndexesMap.remove(_oldValAddr);
      currentValidatorIndexesMap.set(_newValAddr, _index);
    }
  }

  function _setValidator(IStaking.ValidatorCandidate memory _incomingValidator, bool _forced)
    internal
    returns (uint256)
  {
    (bool _success, Validator storage _currentValidator) = _tryGetValidator(_incomingValidator.consensusAddr);
    if (_success && _forced) {
      return __setExistedValidator(_incomingValidator, _currentValidator);
    }
    return __setUnexistentValidator(_incomingValidator);
  }

  function _removeValidatorAtMiningIndex(uint256 _miningIndex) internal {
    (address _oldValAddr, ) = currentValidatorIndexesMap.at(_miningIndex);
    currentValidatorIndexesMap.remove(_oldValAddr);
  }

  function _getValidatorAtMiningIndex(uint256 _miningIndex) internal view returns (Validator storage) {
    (, uint256 _index) = currentValidatorIndexesMap.at(_miningIndex);
    require(_index != 0, string(abi.encodePacked("Nonexistent validator at index ", _miningIndex)));
    return validatorSet[_index];
  }

  function _getValidator(address _valAddr) internal view returns (Validator storage) {
    (bool _success, Validator storage _v) = _tryGetValidator(_valAddr);
    require(_success, string(abi.encodePacked("Nonexistent validator ", _valAddr)));
    return _v;
  }

  function _tryGetValidator(address _valAddr) internal view returns (bool, Validator storage) {
    uint256 _index = validatorSetMap[_valAddr];
    Validator storage _v = validatorSet[_index];
    if (_index == 0) {
      return (false, _v);
    }
    return (true, _v);
  }

  function _isSameValidator(IStaking.ValidatorCandidate memory _v1, Validator memory _v2) internal pure returns (bool) {
    return _v1.consensusAddr == _v2.consensusAddr && _v1.treasuryAddr == _v2.treasuryAddr;
  }

  function __setExistedValidator(
    IStaking.ValidatorCandidate memory _incomingValidator,
    Validator storage _currentValidator
  ) private returns (uint256) {
    _currentValidator.consensusAddr = _incomingValidator.consensusAddr;
    _currentValidator.treasuryAddr = _incomingValidator.treasuryAddr;

    return validatorSetMap[_currentValidator.consensusAddr];
  }

  function __setUnexistentValidator(IStaking.ValidatorCandidate memory _incomingValidator) private returns (uint256) {
    uint256 index = validatorSet.length;

    validatorSetMap[_incomingValidator.consensusAddr] = index;
    Validator storage _v = validatorSet.push();
    _v.consensusAddr = _incomingValidator.consensusAddr;
    _v.treasuryAddr = _incomingValidator.treasuryAddr;

    return index;
  }
}
