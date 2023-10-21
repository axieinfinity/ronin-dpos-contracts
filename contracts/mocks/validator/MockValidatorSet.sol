// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../interfaces/validator/IRoninValidatorSet.sol";
import "../../ronin/validator/CandidateManager.sol";
import { HasStakingVestingDeprecated, HasSlashIndicatorDeprecated } from "../../utils/DeprecatedSlots.sol";

contract MockValidatorSet is
  IRoninValidatorSet,
  CandidateManager,
  HasStakingVestingDeprecated,
  HasSlashIndicatorDeprecated
{
  uint256 internal _lastUpdatedPeriod;
  uint256 internal _numberOfBlocksInEpoch;
  /// @dev Mapping from period number => slashed
  mapping(uint256 => bool) internal _periodSlashed;

  constructor(
    address __stakingContract,
    address _slashIndicatorContract,
    address _stakingVestingContract,
    uint256 __maxValidatorCandidate,
    uint256 __numberOfBlocksInEpoch,
    uint256 __minEffectiveDaysOnwards
  ) {
    _setContract(ContractType.STAKING, __stakingContract);
    _setContract(ContractType.SLASH_INDICATOR, _slashIndicatorContract);
    _setContract(ContractType.STAKING_VESTING, _stakingVestingContract);
    _setMaxValidatorCandidate(__maxValidatorCandidate);
    _numberOfBlocksInEpoch = __numberOfBlocksInEpoch;
    _minEffectiveDaysOnwards = __minEffectiveDaysOnwards;
  }

  function submitBlockReward() external payable override {}

  function wrapUpEpoch() external payable override {
    _syncCandidateSet(_lastUpdatedPeriod + 1);
    _lastUpdatedPeriod = currentPeriod();
  }

  function getLastUpdatedBlock() external view override returns (uint256) {}

  function checkManyJailed(address[] calldata) external view override returns (bool[] memory) {}

  function checkMiningRewardDeprecatedAtPeriod(address, uint256 _period) external view override returns (bool) {}

  function checkMiningRewardDeprecated(address) external view override returns (bool) {}

  function checkBridgeRewardDeprecatedAtPeriod(
    address _consensusAddr,
    uint256 _period
  ) external view returns (bool _result) {}

  function epochOf(uint256 _block) external view override returns (uint256) {}

  function getValidators() external view override returns (address[] memory) {}

  function epochEndingAt(uint256 _block) external view override returns (bool) {}

  function execSlash(
    address validatorAddr,
    uint256 newJailedUntil,
    uint256 slashAmount,
    bool cannotBailout
  ) external override {}

  function execBailOut(address, uint256) external override {}

  function setMaxValidatorNumber(uint256 _maxValidatorNumber) external override {}

  function setMaxPrioritizedValidatorNumber(uint256 _maxPrioritizedValidatorNumber) external override {}

  function maxValidatorNumber() external view override returns (uint256 _maximumValidatorNumber) {}

  function maxPrioritizedValidatorNumber()
    external
    view
    override
    returns (uint256 _maximumPrioritizedValidatorNumber)
  {}

  function numberOfBlocksInEpoch() public view override returns (uint256) {
    return _numberOfBlocksInEpoch;
  }

  function getBlockProducers() external view override returns (address[] memory) {}

  function isBlockProducer(address) external pure override returns (bool) {
    return true;
  }

  function totalBlockProducer() external view override returns (uint256) {}

  function tryGetPeriodOfEpoch(uint256) external view returns (bool, uint256) {}

  function isPeriodEnding() public view virtual returns (bool) {
    return currentPeriod() > _lastUpdatedPeriod;
  }

  function currentPeriod() public view override returns (uint256) {
    return block.timestamp / 86400;
  }

  function checkJailed(address) external view override returns (bool) {}

  function getJailedTimeLeft(address) external view override returns (bool, uint256, uint256) {}

  function currentPeriodStartAtBlock() external view override returns (uint256) {}

  function checkJailedAtBlock(address _addr, uint256 _blockNum) external view override returns (bool) {}

  function getJailedTimeLeftAtBlock(
    address _addr,
    uint256 _blockNum
  ) external view override returns (bool isJailed_, uint256 blockLeft_, uint256 epochLeft_) {}

  function totalDeprecatedReward() external view override returns (uint256) {}

  function execReleaseLockedFundForEmergencyExitRequest(
    address _consensusAddr,
    address payable _recipient
  ) external override {}

  function emergencyExitLockedAmount() external override returns (uint256) {}

  function emergencyExpiryDuration() external override returns (uint256) {}

  function setEmergencyExitLockedAmount(uint256 _emergencyExitLockedAmount) external override {}

  function setEmergencyExpiryDuration(uint256 _emergencyExpiryDuration) external override {}

  function getEmergencyExitInfo(address _consensusAddr) external view override returns (EmergencyExitInfo memory) {}

  function execEmergencyExit(address, uint256) external {}

  function isOperatingBridge(address) external view returns (bool) {}

  function _emergencyExitLockedFundReleased(address _consensusAddr) internal virtual override returns (bool) {}

  function _isTrustedOrg(address _consensusAddr) internal virtual override returns (bool) {}
}
