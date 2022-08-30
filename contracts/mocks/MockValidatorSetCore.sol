// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../ValidatorSetCore.sol";

/**
 * @title Set of validators in current epoch
 * @notice This contract maintains set of validator in the current epoch of Ronin network
 */
contract MockValidatorSetCore is ValidatorSetCore {
  function setValidatorAtMiningIndex(uint256 _miningIndex, IStaking.ValidatorCandidate memory _incomingValidator)
    external
  {
    _setValidatorAtMiningIndex(_miningIndex, _incomingValidator);
  }

  function setValidator(IStaking.ValidatorCandidate memory _incomingValidator, bool _forced)
    external
    returns (uint256)
  {
    return _setValidator(_incomingValidator, _forced);
  }

  function removeValidatorAtMiningIndex(uint256 _miningIndex) external {
    _removeValidatorAtMiningIndex(_miningIndex);
  }

  function getValidatorAtMiningIndex(uint256 _miningIndex) external view returns (IValidatorSet.Validator memory) {
    return _getValidatorAtMiningIndex(_miningIndex);
  }

  function getValidator(address _valAddr) external view returns (IValidatorSet.Validator memory) {
    return _getValidator(_valAddr);
  }

  function tryGetValidator(address _valAddr) external view returns (bool, IValidatorSet.Validator memory, uint256) {
    return _tryGetValidator(_valAddr);
  }

  function isSameValidator(IStaking.ValidatorCandidate memory _v1, IValidatorSet.Validator memory _v2)
    external
    pure
    returns (bool)
  {
    return _isSameValidator(_v1, _v2);
  }
}
