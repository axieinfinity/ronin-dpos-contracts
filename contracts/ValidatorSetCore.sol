// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "./interfaces/IValidatorSet.sol";
import "./interfaces/IStaking.sol";

/**
 * @title Set of validators in current epoch
 * @notice This contract maintains set of validator in the current epoch of Ronin network
 */
abstract contract ValidatorSetCore {
  using EnumerableMap for EnumerableMap.AddressToUintMap;

  /// @dev Array of all validators. The element at 0-slot is reserved for unknown validator.
  IValidatorSet.Validator[] public validatorSet;
  /// @dev Map of array of all validators
  mapping(address => uint) public validatorSetMap;
  /// @dev Enumerable map of indexes of the current validator set, e.g. the array [0, 3, 4, 1] tells
  /// the sequence of validators to mine block in the next epoch will be at the 3-, 4- and 1-index,
  /// One can query the mining order of an arbitrary address by this enumerable map. This array is
  /// indexed from 1, and its content is non-zero value, due to reserved 0-slot in `validatorSet`.
  uint[] internal currentValidatorIndexes;
  mapping(address => uint) currentValidatorIndexesMap;

  constructor() {
    // Add empty validator at 0-slot for the set map
    validatorSet.push();
    currentValidatorIndexes.push();
  }

  function _isInCurrentValidatorSet(address _addr) internal view returns (bool) {
    return (currentValidatorIndexesMap[_addr] != 0);
  }

  function _getCurrentValidatorSetSize() internal view returns (uint) {
    return currentValidatorIndexes.length - 1;
  }

  function _setValidatorAtMiningIndex(uint _miningIndex, IStaking.ValidatorCandidate memory _incomingValidator)
    internal
  {
    require(_miningIndex > 0, "Validator: Cannot set at 0-index of mining set");
    uint _length = currentValidatorIndexes.length;
    require(_miningIndex <= _length, "Validator: Cannot set at out-of-bound mining set");

    address _newValAddr = _incomingValidator.consensusAddr;
    uint _incomingIndex = _setValidator(_incomingValidator, false);

    currentValidatorIndexesMap[_newValAddr] = _miningIndex;
    if (_miningIndex < _length) {
      currentValidatorIndexes[_miningIndex] = _incomingIndex;
    } else {
      currentValidatorIndexes.push(_incomingIndex);
    }
  }

  /**
   * @return validatorIndex_ Actual index of the validator in the `validatorSet`
   */
  function _setValidator(IStaking.ValidatorCandidate memory _incomingValidator, bool _forcedIfExist)
    internal
    returns (uint validatorIndex_)
  {
    (bool _success, IValidatorSet.Validator storage _currentValidator, uint _actualIndex) = _tryGetValidator(
      _incomingValidator.consensusAddr
    );

    if (!_success) {
      return __setUnexistentValidator(_incomingValidator);
    } else {
      if (_forcedIfExist) {
        return __setExistedValidator(_incomingValidator, _currentValidator);
      } else {
        return _actualIndex;
      }
    }
  }

  function _popValidatorFromMiningIndex() internal {
    uint _length = currentValidatorIndexes.length - 1;
    require(_length > 1, "Validator: Cannot remove the last element"); 

    IValidatorSet.Validator storage _lastValidatorInEpoch = validatorSet[currentValidatorIndexes[_length]]; 
    currentValidatorIndexesMap[_lastValidatorInEpoch.consensusAddr] = 0;
    currentValidatorIndexes.pop();
  }

  function _getValidatorAtMiningIndex(uint _miningIndex) internal view returns (IValidatorSet.Validator storage) {
    require(_miningIndex < currentValidatorIndexes.length, "Validator: No validator exists at queried mining index");
    uint _actualIndex = currentValidatorIndexes[_miningIndex];
    require(_actualIndex != 0, "Validator: No validator exists at mining index 0");
    return validatorSet[_actualIndex];
  }

  function _getValidator(address _valAddr) internal view returns (IValidatorSet.Validator storage) {
    (bool _success, IValidatorSet.Validator storage _v, ) = _tryGetValidator(_valAddr);
    require(_success, string(abi.encodePacked("Validator: Nonexistent validator ", _valAddr)));
    return _v;
  }

  function _tryGetValidator(address _valAddr)
    internal
    view
    returns (
      bool,
      IValidatorSet.Validator storage,
      uint
    )
  {
    uint _actualIndex = validatorSetMap[_valAddr];
    IValidatorSet.Validator storage _v = validatorSet[_actualIndex];
    if (_actualIndex == 0) {
      return (false, _v, 0);
    }
    return (true, _v, _actualIndex);
  }

  function _isSameValidator(IStaking.ValidatorCandidate memory _v1, IValidatorSet.Validator memory _v2)
    internal
    pure
    returns (bool)
  {
    return _v1.consensusAddr == _v2.consensusAddr && _v1.treasuryAddr == _v2.treasuryAddr;
  }

  function __setExistedValidator(
    IStaking.ValidatorCandidate memory _incomingValidator,
    IValidatorSet.Validator storage _currentValidator
  ) private returns (uint) {
    _currentValidator.consensusAddr = _incomingValidator.consensusAddr;
    _currentValidator.treasuryAddr = _incomingValidator.treasuryAddr;

    return validatorSetMap[_currentValidator.consensusAddr];
  }

  function __setUnexistentValidator(IStaking.ValidatorCandidate memory _incomingValidator) private returns (uint) {
    uint _actualIndex = validatorSet.length;

    validatorSetMap[_incomingValidator.consensusAddr] = _actualIndex;
    IValidatorSet.Validator storage _v = validatorSet.push();
    _v.consensusAddr = _incomingValidator.consensusAddr;
    _v.treasuryAddr = _incomingValidator.treasuryAddr;

    return _actualIndex;
  }
}
