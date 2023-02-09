// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../interfaces/validator/IRoninValidatorSet.sol";
import "../../ronin/validator/CandidateManager.sol";

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
    uint256 __numberOfBlocksInEpoch,
    uint256 __minEffectiveDaysOnwards
  ) {
    _setStakingContract(__stakingContract);
    _setMaxValidatorCandidate(__maxValidatorCandidate);
    slashIndicatorContract = _slashIndicatorContract;
    stakingVestingContract = _stakingVestingContract;
    _numberOfBlocksInEpoch = __numberOfBlocksInEpoch;
    _minEffectiveDaysOnwards = __minEffectiveDaysOnwards;
  }

  function submitBlockReward() external payable override {}

  function wrapUpEpoch() external payable override {
    _syncCandidateSet();
    _lastUpdatedPeriod = currentPeriod();
  }

  function getLastUpdatedBlock() external view override returns (uint256) {}

  function checkManyJailed(address[] calldata) external view override returns (bool[] memory) {}

  function checkMiningRewardDeprecatedAtPeriod(address[] calldata, uint256 _period)
    external
    view
    override
    returns (bool[] memory)
  {}

  function checkMiningRewardDeprecated(address[] calldata) external view override returns (bool[] memory) {}

  function epochOf(uint256 _block) external view override returns (uint256) {}

  function getValidators() external view override returns (address[] memory) {}

  function epochEndingAt(uint256 _block) external view override returns (bool) {}

  function execSlash(
    address _validatorAddr,
    uint256 _newJailedUntil,
    uint256 _slashAmount,
    bool _cannotBailout
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

  function isValidator(address) external pure override returns (bool) {
    return true;
  }

  function numberOfBlocksInEpoch() public view override returns (uint256) {
    return _numberOfBlocksInEpoch;
  }

  function getBridgeOperators() external view override returns (address[] memory) {}

  function getBridgeOperatorsOf(address[] memory _validatorAddrs) external view override returns (address[] memory) {}

  function isBridgeOperator(address) external pure override returns (bool) {
    return true;
  }

  function totalBridgeOperators() external view override returns (uint256) {}

  function getBlockProducers() external view override returns (address[] memory) {}

  function isBlockProducer(address) external pure override returns (bool) {
    return true;
  }

  function totalBlockProducers() external view override returns (uint256) {}

  function tryGetPeriodOfEpoch(uint256) external view returns (bool, uint256) {}

  function isPeriodEnding() public view virtual returns (bool) {
    return currentPeriod() > _lastUpdatedPeriod;
  }

  function currentPeriod() public view override returns (uint256) {
    return block.timestamp / 86400;
  }

  function checkJailed(address) external view override returns (bool) {}

  function getJailedTimeLeft(address)
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

  function checkJailedAtBlock(address _addr, uint256 _blockNum) external view override returns (bool) {}

  function getJailedTimeLeftAtBlock(address _addr, uint256 _blockNum)
    external
    view
    override
    returns (
      bool isJailed_,
      uint256 blockLeft_,
      uint256 epochLeft_
    )
  {}

  function totalDeprecatedReward() external view override returns (uint256) {}

  function _bridgeOperatorOf(address _consensusAddr) internal view override returns (address) {
    return super._bridgeOperatorOf(_consensusAddr);
  }

  function execReleaseLockedFundForEmergencyExitRequest(address _consensusAddr, address payable _recipient)
    external
    override
  {}

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
