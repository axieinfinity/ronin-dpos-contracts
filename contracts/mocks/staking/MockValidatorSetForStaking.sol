// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../interfaces/IValidatorSet.sol";
import "../../interfaces/IStaking.sol";

contract MockValidatorSetForStaking is IValidatorSet {
  IStaking public stakingContract;

  uint256 public numberOfEpochsInPeriod;
  uint256 public numberOfBlocksInEpoch;
  /// @dev Mapping from period number => slashed
  mapping(uint256 => bool) internal _periodSlashed;
  uint256[] internal _periods;

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
    stakingContract.recordReward{ value: msg.value }(msg.sender, msg.value);
  }

  function settledReward(address[] calldata _validatorList) external {
    stakingContract.settleMultipleRewardPools(_validatorList);
  }

  function slashMisdemeanor(address _validator) external override {
    stakingContract.sinkPendingReward(_validator);
  }

  function slashFelony(address _validator) external override {
    stakingContract.sinkPendingReward(_validator);
    stakingContract.deductStakingAmount(_validator, 1);
  }

  function slashDoubleSign(address _validator) external override {
    stakingContract.sinkPendingReward(_validator);
  }

  function endPeriod() external {
    _periods.push(block.number);
  }

  function periodOf(uint256 _block) external view override returns (uint256 _period) {
    for (uint256 _i; _i < _periods.length; _i++) {
      if (_block >= _periods[_i]) {
        _period = _i + 1;
      }
    }
  }

  function updateValidators() external override returns (address[] memory) {}

  function getValidators() external view override returns (address[] memory) {}

  function isValidator(address validator) external view override returns (bool) {}

  function isWorkingValidator(address validator) external view override returns (bool) {}

  function isCurrentValidator(address validator) external view override returns (bool) {}

  function getLastUpdated() external view override returns (uint256 height) {}
}
