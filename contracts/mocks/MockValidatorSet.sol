// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../interfaces/ISlashIndicator.sol";
import "../interfaces/IRoninValidatorSet.sol";
import "../interfaces/IStaking.sol";

contract MockValidatorSet is IRoninValidatorSet {
  address public stakingContract;
  address public stakingVestingContract;
  address public slashIndicatorContract;

  uint256 public numberOfEpochsInPeriod;
  uint256 public numberOfBlocksInEpoch;
  /// @dev Mapping from period number => slashed
  mapping(uint256 => bool) internal _periodSlashed;
  uint256[] internal _periods;

  constructor(
    address _stakingContract,
    address _slashIndicatorContract,
    address _stakingVestingContract,
    uint256 _numberOfEpochsInPeriod,
    uint256 _numberOfBlocksInEpoch
  ) {
    stakingContract = _stakingContract;
    slashIndicatorContract = _slashIndicatorContract;
    stakingVestingContract = _stakingVestingContract;
    numberOfEpochsInPeriod = _numberOfEpochsInPeriod;
    numberOfBlocksInEpoch = _numberOfBlocksInEpoch;
  }

  function depositReward() external payable {
    IStaking(stakingContract).recordReward{ value: msg.value }(msg.sender, msg.value);
  }

  function settledReward(address[] calldata _validatorList) external {
    IStaking(stakingContract).settleRewardPools(_validatorList);
  }

  function slashMisdemeanor(address _validator) external {
    IStaking(stakingContract).sinkPendingReward(_validator);
  }

  function slashFelony(address _validator) external {
    IStaking(stakingContract).sinkPendingReward(_validator);
    IStaking(stakingContract).deductStakingAmount(_validator, 1);
  }

  function slashDoubleSign(address _validator) external {
    IStaking(stakingContract).sinkPendingReward(_validator);
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

  function submitBlockReward() external payable override {}

  function wrapUpEpoch() external payable override {}

  function getLastUpdatedBlock() external view override returns (uint256) {}

  function governanceAdmin() external view override returns (address) {}

  function jailed(address[] memory) external view override returns (bool[] memory) {}

  function rewardDeprecated(address[] memory, uint256 _period) external view override returns (bool[] memory) {}

  function epochOf(uint256 _block) external view override returns (uint256) {}

  function getValidators() external view override returns (address[] memory) {}

  function epochEndingAt(uint256 _block) external view override returns (bool) {}

  function periodEndingAt(uint256 _block) external view override returns (bool) {}

  function slash(
    address _validatorAddr,
    uint256 _newJailedUntil,
    uint256 _slashAmount
  ) external override {}

  function resetCounters(address[] calldata _validatorAddrs) external {
    ISlashIndicator(slashIndicatorContract).resetCounters(_validatorAddrs);
  }

  function setGovernanceAdmin(address _governanceAdmin) external override {}

  function setMaxValidatorNumber(uint256 _maxValidatorNumber) external override {}

  function setNumberOfBlocksInEpoch(uint256 _numberOfBlocksInEpoch) external override {}

  function setNumberOfEpochsInPeriod(uint256 _numberOfEpochsInPeriod) external override {}
}
