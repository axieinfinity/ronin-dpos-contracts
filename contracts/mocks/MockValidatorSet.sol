// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../interfaces/ISlashIndicator.sol";
import "../interfaces/IRoninValidatorSet.sol";
import "../interfaces/IStaking.sol";
import "../validator/CandidateManager.sol";

contract MockValidatorSet is IRoninValidatorSet, CandidateManager {
  address public stakingVestingContract;
  address public slashIndicatorContract;

  uint256 internal _numberOfEpochsInPeriod;
  uint256 internal _numberOfBlocksInEpoch;
  /// @dev Mapping from period number => slashed
  mapping(uint256 => bool) internal _periodSlashed;
  uint256[] internal _periods;

  constructor(
    address __stakingContract,
    address _slashIndicatorContract,
    address _stakingVestingContract,
    uint256 __maxValidatorCandidate,
    uint256 __numberOfEpochsInPeriod,
    uint256 __numberOfBlocksInEpoch
  ) {
    _setStakingContract(__stakingContract);
    _setMaxValidatorCandidate(__maxValidatorCandidate);
    slashIndicatorContract = _slashIndicatorContract;
    stakingVestingContract = _stakingVestingContract;
    _numberOfEpochsInPeriod = __numberOfEpochsInPeriod;
    _numberOfBlocksInEpoch = __numberOfBlocksInEpoch;
  }

  function depositReward() external payable {
    _stakingContract.recordReward{ value: msg.value }(msg.sender, msg.value);
  }

  function settledReward(address[] calldata _validatorList) external {
    _stakingContract.settleRewardPools(_validatorList);
  }

  function slashMisdemeanor(address _validator) external {
    _stakingContract.sinkPendingReward(_validator);
  }

  function slashFelony(address _validator) external {
    _stakingContract.sinkPendingReward(_validator);
    _stakingContract.deductStakedAmount(_validator, 1);
  }

  function slashDoubleSign(address _validator) external {
    _stakingContract.sinkPendingReward(_validator);
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

  function wrapUpEpoch() external payable override {
    _filterUnsatisfiedCandidates(0);
  }

  function getLastUpdatedBlock() external view override returns (uint256) {}

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

  function setMaxValidatorNumber(uint256 _maxValidatorNumber) external override {}

  function setNumberOfBlocksInEpoch(uint256 _number) external override {}

  function setNumberOfEpochsInPeriod(uint256 _number) external override {}

  function maxValidatorNumber() external view override returns (uint256 _maximumValidatorNumber) {}

  function maxPrioritizedValidatorNumber()
    external
    view
    override
    returns (uint256 _maximumPrioritizedValidatorNumber)
  {}

  function setPrioritizedAddresses(address[] memory __validatorAddresses, bool[] memory __prioritizedList)
    external
    override
  {}

  function getPriorityStatus(address _addr) external view override returns (bool) {}

  function isValidator(address) external pure override returns (bool) {
    return true;
  }

  function numberOfEpochsInPeriod() public view override(CandidateManager, ICandidateManager) returns (uint256) {
    return _numberOfEpochsInPeriod;
  }

  function numberOfBlocksInEpoch() public view override(CandidateManager, ICandidateManager) returns (uint256) {
    return _numberOfBlocksInEpoch;
  }
}
