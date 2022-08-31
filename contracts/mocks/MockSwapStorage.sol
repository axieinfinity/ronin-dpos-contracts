// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../interfaces/IValidatorSet.sol";
import "../interfaces/IStaking.sol";

contract MockSwapStorage {
  /// @dev Array of all validators. 
  IStaking.ValidatorCandidate[] public validatorSet;

  function pushValidator(IStaking.ValidatorCandidate memory _incomingValidator)
    external
  {
    validatorSet.push(_incomingValidator);
  }

  function _setValidatorAt(uint256 _index, IStaking.ValidatorCandidate memory _incomingValidator) public {
    require(_index < validatorSet.length, "Access out-of-bound");

    IStaking.ValidatorCandidate storage _validator = validatorSet[_index];
    _validator.stakingAddr = _incomingValidator.stakingAddr;
    _validator.consensusAddr = _incomingValidator.consensusAddr;
    _validator.treasuryAddr = _incomingValidator.treasuryAddr;
    _validator.commissionRate = _incomingValidator.commissionRate;
    _validator.stakedAmount = _incomingValidator.stakedAmount;
    _validator.delegatedAmount = _incomingValidator.delegatedAmount;
    _validator.governing = _incomingValidator.governing;
  }

  function swapValidators(uint256 _i, uint256 _j) external {
    require(_i < validatorSet.length, "Access left element out-of-bound"); 
    require(_j < validatorSet.length, "Access right element out-of-bound"); 
    IStaking.ValidatorCandidate memory _tmp = validatorSet[_i]; 
    _setValidatorAt(_i, validatorSet[_j]);
    _setValidatorAt(_j, _tmp);
  } 
}
