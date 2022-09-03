// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../interfaces/IValidatorSet.sol";
import "../../interfaces/IStaking.sol";

contract MockValidatorSetForStaking is IValidatorSet {
  IStaking public stakingContract;

  uint256 public numberOfEpochsInPeriod;
  uint256 public numberOfBlocksInEpoch;

  constructor(
    IStaking _stakingContract,
    uint256 _numberOfEpochsInPeriod,
    uint256 _numberOfBlocksInEpoch
  ) {
    stakingContract = _stakingContract;
    numberOfEpochsInPeriod = _numberOfEpochsInPeriod;
    numberOfBlocksInEpoch = _numberOfBlocksInEpoch;
  }

  function depositReward() external payable override {
    stakingContract.recordReward(msg.sender, msg.value);
  }

  function settledReward(address[] memory _validatorList) external {
    for (uint _i = 0; _i < _validatorList.length; _i++) {
      stakingContract.settleRewardPool(_validatorList[_i]);
    }
  }

  function slashMisdemeanor(address _validator) external override {
    stakingContract.onValidatorSlashed(_validator);
  }

  function slashFelony(address _validator) external override {
    stakingContract.onValidatorSlashed(_validator);
    stakingContract.deductStakingAmount(_validator, 1);
  }

  function slashDoubleSign(address _validator) external override {
    stakingContract.onValidatorSlashed(_validator);
  }

  function periodOf(uint256 _block) external view override returns (uint256) {
    return _block / numberOfBlocksInEpoch / numberOfEpochsInPeriod + 1;
  }

  function updateValidators() external override returns (address[] memory) {}

  function getValidators() external view override returns (address[] memory) {}

  function isValidator(address validator) external view override returns (bool) {}

  function isWorkingValidator(address validator) external view override returns (bool) {}

  function isCurrentValidator(address validator) external view override returns (bool) {}

  function getLastUpdated() external view override returns (uint256 height) {}
}
