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
    address _stakingContract,
    address _slashIndicatorContract,
    address _stakingVestingContract,
    address _profileContract,
    uint256 __maxValidatorCandidate,
    uint256 __numberOfBlocksInEpoch,
    uint256 __minEffectiveDaysOnwards
  ) {
    _setContract(ContractType.STAKING, _stakingContract);
    _setContract(ContractType.SLASH_INDICATOR, _slashIndicatorContract);
    _setContract(ContractType.STAKING_VESTING, _stakingVestingContract);
    _setContract(ContractType.PROFILE, _profileContract);
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

  function checkManyJailed(TConsensus[] calldata) external view override returns (bool[] memory) {}

  function checkManyJailedById(address[] calldata candidateIds) external view returns (bool[] memory) {}

  function checkMiningRewardDeprecated(TConsensus) external view override returns (bool) {}

  function checkMiningRewardDeprecatedAtPeriod(TConsensus, uint256 period) external view override returns (bool) {}

  function checkBridgeRewardDeprecatedAtPeriod(
    TConsensus _consensusAddr,
    uint256 _period
  ) external view returns (bool _result) {}

  function epochOf(uint256 _block) external view override returns (uint256) {}

  function getValidators() external view override returns (address[] memory) {}

  function epochEndingAt(uint256 _block) external view override returns (bool) {}

  function execSlash(address cid, uint256 newJailedUntil, uint256 slashAmount, bool cannotBailout) external override {}

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

  function isBlockProducer(TConsensus) external pure override returns (bool) {
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

  function checkJailed(TConsensus) external view override returns (bool) {}

  function getJailedTimeLeft(TConsensus) external view override returns (bool, uint256, uint256) {}

  function currentPeriodStartAtBlock() external view override returns (uint256) {}

  function checkJailedAtBlock(TConsensus _addr, uint256 _blockNum) external view override returns (bool) {}

  function getJailedTimeLeftAtBlock(
    TConsensus _addr,
    uint256 _blockNum
  ) external view override returns (bool isJailed_, uint256 blockLeft_, uint256 epochLeft_) {}

  function totalDeprecatedReward() external view override returns (uint256) {}

  function __css2cid(TConsensus consensusAddr) internal view override returns (address) {
    return IProfile(getContract(ContractType.PROFILE)).getConsensus2Id(consensusAddr);
  }

  function __css2cidBatch(TConsensus[] memory consensusAddrs) internal view override returns (address[] memory) {
    return IProfile(getContract(ContractType.PROFILE)).getManyConsensus2Id(consensusAddrs);
  }

  function execReleaseLockedFundForEmergencyExitRequest(
    address _candidateId,
    address payable _recipient
  ) external override {}

  function emergencyExitLockedAmount() external override returns (uint256) {}

  function emergencyExpiryDuration() external override returns (uint256) {}

  function setEmergencyExitLockedAmount(uint256 _emergencyExitLockedAmount) external override {}

  function setEmergencyExpiryDuration(uint256 _emergencyExpiryDuration) external override {}

  function getEmergencyExitInfo(TConsensus consensus) external view override returns (EmergencyExitInfo memory) {}

  function execEmergencyExit(address, uint256) external {}

  function isOperatingBridge(TConsensus) external view returns (bool) {}

  function _emergencyExitLockedFundReleased(address _consensusAddr) internal virtual override returns (bool) {}

  function _isTrustedOrg(address _consensusAddr) internal virtual override returns (bool) {}
}
