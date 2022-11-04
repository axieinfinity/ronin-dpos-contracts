// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../interfaces/slash-indicator/ISlashIndicator.sol";
import "../interfaces/IRoninValidatorSet.sol";
import "../interfaces/IStaking.sol";
import "../ronin/validator/CandidateManager.sol";

contract MockValidatorSet is IRoninValidatorSet, CandidateManager {
  address public stakingVestingContract;
  address public slashIndicatorContract;

  uint256 internal _lastUpdatedPeriod;
  uint256 internal _numberOfBlocksInEpoch;
  /// @dev Mapping from period number => slashed
  mapping(uint256 => bool) internal _periodSlashed;

  constructor(
    address __stakingContract,
    address _slashIndicatorContract,
    address _stakingVestingContract,
    uint256 __maxValidatorCandidate,
    uint256 __numberOfBlocksInEpoch
  ) {
    _setStakingContract(__stakingContract);
    _setMaxValidatorCandidate(__maxValidatorCandidate);
    slashIndicatorContract = _slashIndicatorContract;
    stakingVestingContract = _stakingVestingContract;
    _numberOfBlocksInEpoch = __numberOfBlocksInEpoch;
  }

  function submitBlockReward() external payable override {}

  function wrapUpEpoch() external payable override {
    _filterUnsatisfiedCandidates();
    _lastUpdatedPeriod = currentPeriod();
  }

  function getLastUpdatedBlock() external view override returns (uint256) {}

  function bulkJailed(address[] memory) external view override returns (bool[] memory) {}

  function miningRewardDeprecatedAtPeriod(address[] memory, uint256 _period)
    external
    view
    override
    returns (bool[] memory)
  {}

  function miningRewardDeprecated(address[] memory) external view override returns (bool[] memory) {}

  function epochOf(uint256 _block) external view override returns (uint256) {}

  function getValidators() external view override returns (address[] memory) {}

  function epochEndingAt(uint256 _block) external view override returns (bool) {}

  function slash(
    address _validatorAddr,
    uint256 _newJailedUntil,
    uint256 _slashAmount
  ) external override {}

  function bailOut(address) external override {}

  function setMaxValidatorNumber(uint256 _maxValidatorNumber) external override {}

  function setNumberOfBlocksInEpoch(uint256 _number) external override {}

  function maxValidatorNumber() external view override returns (uint256 _maximumValidatorNumber) {}

  function maxPrioritizedValidatorNumber()
    external
    view
    override
    returns (uint256 _maximumPrioritizedValidatorNumber)
  {}

  function isValidator(address) external pure override returns (bool) {
    return true;
  }

  function numberOfBlocksInEpoch() public view override(CandidateManager, ICandidateManager) returns (uint256) {
    return _numberOfBlocksInEpoch;
  }

  function getBridgeOperators() external view override returns (address[] memory) {}

  function isBridgeOperator(address) external pure override returns (bool) {
    return true;
  }

  function totalBridgeOperators() external view override returns (uint256) {}

  function getBlockProducers() external view override returns (address[] memory) {}

  function isBlockProducer(address) external pure override returns (bool) {
    return true;
  }

  function totalBlockProducers() external view override returns (uint256) {}

  function isPeriodEnding() public view virtual returns (bool) {
    return currentPeriod() > _lastUpdatedPeriod;
  }

  function currentPeriod() public view override(CandidateManager, ICandidateManager) returns (uint256) {
    return block.timestamp / 86400;
  }

  function jailed(address) external view override returns (bool) {}

  function jailedTimeLeft(address)
    external
    view
    override
    returns (
      bool,
      uint256,
      uint256
    )
  {}

  function currentPeriodStartAtBlock() external view override returns (uint256) {}

  function jailedAtBlock(address _addr, uint256 _blockNum) external view override returns (bool) {}

  function jailedTimeLeftAtBlock(address _addr, uint256 _blockNum)
    external
    view
    override
    returns (
      bool isJailed_,
      uint256 blockLeft_,
      uint256 epochLeft_
    )
  {}
}
