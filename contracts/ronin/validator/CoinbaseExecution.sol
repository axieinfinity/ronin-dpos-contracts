// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/collections/HasBridgeTrackingContract.sol";
import "../../extensions/collections/HasMaintenanceContract.sol";
import "../../extensions/collections/HasSlashIndicatorContract.sol";
import "../../extensions/collections/HasStakingVestingContract.sol";
import "../../extensions/RONTransferHelper.sol";
import "../../interfaces/validator/ICoinbaseExecution.sol";
import "../../libraries/EnumFlags.sol";
import "../../libraries/Math.sol";
import "../../precompile-usages/PrecompileUsageSortValidators.sol";
import "../../precompile-usages/PrecompileUsagePickValidatorSet.sol";
import "./storage-fragments/CommonStorage.sol";
import "./CandidateManager.sol";

abstract contract CoinbaseExecution is
  ICoinbaseExecution,
  RONTransferHelper,
  PrecompileUsageSortValidators,
  PrecompileUsagePickValidatorSet,
  HasStakingVestingContract,
  HasBridgeTrackingContract,
  HasMaintenanceContract,
  HasSlashIndicatorContract,
  CandidateManager,
  CommonStorage
{
  using EnumFlags for EnumFlags.ValidatorFlag;

  modifier onlyCoinbase() {
    require(msg.sender == block.coinbase, "RoninValidatorSet: method caller must be coinbase");
    _;
  }

  modifier whenEpochEnding() {
    require(epochEndingAt(block.number), "RoninValidatorSet: only allowed at the end of epoch");
    _;
  }

  modifier oncePerEpoch() {
    require(
      epochOf(_lastUpdatedBlock) < epochOf(block.number),
      "RoninValidatorSet: query for already wrapped up epoch"
    );
    _lastUpdatedBlock = block.number;
    _;
  }

  /**
   * @inheritdoc ICoinbaseExecution
   */
  function submitBlockReward() external payable override onlyCoinbase {
    uint256 _submittedReward = msg.value;
    address _coinbaseAddr = msg.sender;
    bool _requestForBlockProducer = isBlockProducer(_coinbaseAddr) &&
      !_jailed(_coinbaseAddr) &&
      !_miningRewardDeprecated(_coinbaseAddr, currentPeriod());
    bool _requestForBridgeOperator = true;

    (, uint256 _blockProducerBonus, uint256 _bridgeOperatorBonus) = _stakingVestingContract.requestBonus(
      _requestForBlockProducer,
      _requestForBridgeOperator
    );

    _totalBridgeReward += _bridgeOperatorBonus;

    // Deprecates reward for non-validator or slashed validator
    if (!_requestForBlockProducer) {
      emit BlockRewardDeprecated(_coinbaseAddr, _submittedReward, BlockRewardDeprecatedType.UNAVAILABILITY);
      return;
    }

    emit BlockRewardSubmitted(_coinbaseAddr, _submittedReward, _blockProducerBonus);

    uint256 _period = currentPeriod();
    uint256 _reward = _submittedReward + _blockProducerBonus;
    uint256 _cutOffReward;
    if (_miningRewardBailoutCutOffAtPeriod[_coinbaseAddr][_period]) {
      (, , , uint256 _cutOffPercentage) = _slashIndicatorContract.getCreditScoreConfigs();
      _cutOffReward = (_reward * _cutOffPercentage) / _MAX_PERCENTAGE;
      emit BlockRewardDeprecated(_coinbaseAddr, _cutOffReward, BlockRewardDeprecatedType.AFTER_BAILOUT);
    }

    _reward -= _cutOffReward;
    uint256 _rate = _candidateInfo[_coinbaseAddr].commissionRate;
    uint256 _miningAmount = (_rate * _reward) / _MAX_PERCENTAGE;
    _miningReward[_coinbaseAddr] += _miningAmount;

    uint256 _delegatingAmount = _reward - _miningAmount;
    _delegatingReward[_coinbaseAddr] += _delegatingAmount;
  }

  /**
   * @inheritdoc ICoinbaseExecution
   */
  function wrapUpEpoch() external payable virtual override onlyCoinbase whenEpochEnding oncePerEpoch {
    uint256 _newPeriod = _computePeriod(block.timestamp);
    bool _periodEnding = _isPeriodEnding(_newPeriod);
    _currentPeriodStartAtBlock = block.number + 1;

    address[] memory _currentValidators = getValidators();
    uint256 _epoch = epochOf(block.number);
    uint256 _lastPeriod = currentPeriod();

    if (_periodEnding) {
      _syncBridgeOperatingReward(_lastPeriod, _currentValidators);
      (
        uint256 _totalDelegatingReward,
        uint256[] memory _delegatingRewards
      ) = _distributeRewardToTreasuriesAndCalculateTotalDelegatingReward(_lastPeriod, _currentValidators);
      _settleAndTransferDelegatingRewards(_lastPeriod, _currentValidators, _totalDelegatingReward, _delegatingRewards);
      _slashIndicatorContract.updateCreditScores(_currentValidators, _lastPeriod);
      _currentValidators = _syncValidatorSet(_newPeriod);
    }

    _revampBlockProducers(_newPeriod, _currentValidators);
    emit WrappedUpEpoch(_lastPeriod, _epoch, _periodEnding);
    _lastUpdatedPeriod = _newPeriod;
  }

  /**
   * @dev This loop over the all current validators to sync the bridge operating reward.
   *
   * Note: This method should be called once in the end of each period.
   *
   */
  function _syncBridgeOperatingReward(uint256 _lastPeriod, address[] memory _currentValidators) internal {
    IBridgeTracking _bridgeTracking = _bridgeTrackingContract;
    uint256 _totalBridgeBallots = _bridgeTracking.totalBallots(_lastPeriod);
    uint256 _totalBridgeVotes = _bridgeTracking.totalVotes(_lastPeriod);
    uint256[] memory _bridgeBallots = _bridgeTracking.getManyTotalBallots(_lastPeriod, _currentValidators);
    (
      uint256 _missingVotesRatioTier1,
      uint256 _missingVotesRatioTier2,
      uint256 _jailDurationForMissingVotesRatioTier2,
      uint256 _skipBridgeOperatorSlashingThreshold
    ) = _slashIndicatorContract.getBridgeOperatorSlashingConfigs();
    for (uint _i = 0; _i < _currentValidators.length; _i++) {
      _updateValidatorRewardBaseOnBridgeOperatingPerformance(
        _lastPeriod,
        _currentValidators[_i],
        _bridgeBallots[_i],
        _totalBridgeVotes,
        _totalBridgeBallots,
        _missingVotesRatioTier1,
        _missingVotesRatioTier2,
        _jailDurationForMissingVotesRatioTier2,
        _skipBridgeOperatorSlashingThreshold
      );
    }
  }

  /**
   * @dev Updates validator reward based on the corresponding bridge operator performance.
   */
  function _updateValidatorRewardBaseOnBridgeOperatingPerformance(
    uint256 _period,
    address _validator,
    uint256 _validatorBallots,
    uint256 _totalVotes,
    uint256 _totalBallots,
    uint256 _ratioTier1,
    uint256 _ratioTier2,
    uint256 _jailDurationTier2,
    uint256 _skipBridgeOperatorSlashingThreshold
  ) internal {
    // Shares equally in case the bridge has nothing to votes
    bool _emptyBallot = _totalBallots == 0;
    if (_emptyBallot && _totalVotes == 0) {
      _bridgeOperatingReward[_validator] = _totalBridgeReward / totalBridgeOperators();
      return;
    } else if (_emptyBallot) {
      return;
    }

    // Skips slashing in case the total number of votes is too small
    if (_totalVotes <= _skipBridgeOperatorSlashingThreshold) {
      _bridgeOperatingReward[_validator] = _totalBridgeReward / _totalBallots;
      return;
    }

    uint256 _votedRatio = (_validatorBallots * _MAX_PERCENTAGE) / _totalVotes;
    uint256 _missedRatio = _MAX_PERCENTAGE - _votedRatio;
    if (_missedRatio > _ratioTier2) {
      _bridgeRewardDeprecatedAtPeriod[_validator][_period] = true;
      _miningRewardDeprecatedAtPeriod[_validator][_period] = true;
      _jailedUntil[_validator] = Math.max(block.number + _jailDurationTier2, _jailedUntil[_validator]);
      emit ValidatorPunished(_validator, _period, _jailedUntil[_validator], 0, true, true);
    } else if (_missedRatio > _ratioTier1) {
      _bridgeRewardDeprecatedAtPeriod[_validator][_period] = true;
      emit ValidatorPunished(_validator, _period, _jailedUntil[_validator], 0, false, true);
    } else if (_totalBallots > 0) {
      _bridgeOperatingReward[_validator] = _totalBridgeReward / _totalBallots;
    }
  }

  /**
   * @dev This loops over all current validators to:
   * - Update delegating reward for and calculate total delegating rewards to be sent to the staking contract,
   * - Distribute the reward of block producers and bridge operators to their treasury addresses,
   * - Update the total deprecated reward if the two previous conditions do not sastify.
   *
   * Note: This method should be called once in the end of each period.
   *
   */
  function _distributeRewardToTreasuriesAndCalculateTotalDelegatingReward(
    uint256 _lastPeriod,
    address[] memory _currentValidators
  ) private returns (uint256 _totalDelegatingReward, uint256[] memory _delegatingRewards) {
    address _consensusAddr;
    address payable _treasury;
    _delegatingRewards = new uint256[](_currentValidators.length);
    for (uint _i = 0; _i < _currentValidators.length; _i++) {
      _consensusAddr = _currentValidators[_i];
      _treasury = _candidateInfo[_consensusAddr].treasuryAddr;

      if (!_bridgeRewardDeprecated(_consensusAddr, _lastPeriod)) {
        _distributeBridgeOperatingReward(_consensusAddr, _candidateInfo[_consensusAddr].bridgeOperatorAddr, _treasury);
      } else {
        _totalDeprecatedReward += _bridgeOperatingReward[_consensusAddr];
      }

      if (!_jailed(_consensusAddr) && !_miningRewardDeprecated(_consensusAddr, _lastPeriod)) {
        _totalDelegatingReward += _delegatingReward[_consensusAddr];
        _delegatingRewards[_i] = _delegatingReward[_consensusAddr];
        _distributeMiningReward(_consensusAddr, _treasury);
      } else {
        _totalDeprecatedReward += _miningReward[_consensusAddr] + _delegatingReward[_consensusAddr];
      }

      delete _delegatingReward[_consensusAddr];
      delete _miningReward[_consensusAddr];
      delete _bridgeOperatingReward[_consensusAddr];
    }
    delete _totalBridgeReward;
  }

  /**
   * @dev Distributes bonus of staking vesting and mining fee for the block producer.
   *
   * Emits the `MiningRewardDistributed` once the reward is distributed successfully.
   * Emits the `MiningRewardDistributionFailed` once the contract fails to distribute reward.
   *
   * Note: This method should be called once in the end of each period.
   *
   */
  function _distributeMiningReward(address _consensusAddr, address payable _treasury) private {
    uint256 _amount = _miningReward[_consensusAddr];
    if (_amount > 0) {
      if (_unsafeSendRON(_treasury, _amount)) {
        emit MiningRewardDistributed(_consensusAddr, _treasury, _amount);
        return;
      }

      emit MiningRewardDistributionFailed(_consensusAddr, _treasury, _amount, address(this).balance);
    }
  }

  /**
   * @dev Distribute bonus of staking vesting for the bridge operator.
   *
   * Emits the `BridgeOperatorRewardDistributed` once the reward is distributed successfully.
   * Emits the `BridgeOperatorRewardDistributionFailed` once the contract fails to distribute reward.
   *
   * Note: This method should be called once in the end of each period.
   *
   */
  function _distributeBridgeOperatingReward(
    address _consensusAddr,
    address _bridgeOperator,
    address payable _treasury
  ) private {
    uint256 _amount = _bridgeOperatingReward[_consensusAddr];
    if (_amount > 0) {
      if (_unsafeSendRON(_treasury, _amount)) {
        emit BridgeOperatorRewardDistributed(_consensusAddr, _bridgeOperator, _treasury, _amount);
        return;
      }

      emit BridgeOperatorRewardDistributionFailed(
        _consensusAddr,
        _bridgeOperator,
        _treasury,
        _amount,
        address(this).balance
      );
    }
  }

  /**
   * @dev Helper function to settle rewards for delegators of `_currentValidators` at the end of each period,
   * then transfer the rewards from this contract to the staking contract, in order to finalize a period.
   *
   * Emits the `StakingRewardDistributed` once the reward is distributed successfully.
   * Emits the `StakingRewardDistributionFailed` once the contract fails to distribute reward.
   *
   * Note: This method should be called once in the end of each period.
   *
   */
  function _settleAndTransferDelegatingRewards(
    uint256 _period,
    address[] memory _currentValidators,
    uint256 _totalDelegatingReward,
    uint256[] memory _delegatingRewards
  ) private {
    IStaking _staking = _stakingContract;
    if (_totalDelegatingReward > 0) {
      if (_unsafeSendRON(payable(address(_staking)), _totalDelegatingReward)) {
        _staking.recordRewards(_currentValidators, _delegatingRewards, _period);
        emit StakingRewardDistributed(_totalDelegatingReward);
        return;
      }

      emit StakingRewardDistributionFailed(_totalDelegatingReward, address(this).balance);
    }
  }

  /**
   * @dev Updates the validator set based on the validator candidates from the Staking contract.
   *
   * Emits the `ValidatorSetUpdated` event.
   * Emits the `BridgeOperatorSetUpdated` event.
   *
   * Note: This method should be called once in the end of each period.
   *
   */
  function _syncValidatorSet(uint256 _newPeriod) private returns (address[] memory _newValidators) {
    _removeUnsatisfiedCandidates();
    uint256[] memory _weights = _stakingContract.getManyStakingTotals(_candidates);
    uint256[] memory _trustedWeights = _roninTrustedOrganizationContract.getConsensusWeights(_candidates);
    uint256 _newValidatorCount;
    (_newValidators, _newValidatorCount) = _pcPickValidatorSet(
      _candidates,
      _weights,
      _trustedWeights,
      _maxValidatorNumber,
      _maxPrioritizedValidatorNumber
    );
    _setNewValidatorSet(_newValidators, _newValidatorCount, _newPeriod);
    emit BridgeOperatorSetUpdated(_newPeriod, getBridgeOperators());
  }

  /**
   * @dev Private helper function helps writing the new validator set into the contract storage.
   *
   * Emits the `ValidatorSetUpdated` event.
   *
   * Note: This method should be called once in the end of each period.
   *
   */
  function _setNewValidatorSet(
    address[] memory _newValidators,
    uint256 _newValidatorCount,
    uint256 _newPeriod
  ) private {
    for (uint256 _i = _newValidatorCount; _i < validatorCount; _i++) {
      delete _validatorMap[_validators[_i]];
      delete _validators[_i];
    }

    uint256 _count;
    for (uint256 _i = 0; _i < _newValidatorCount; _i++) {
      address _newValidator = _newValidators[_i];
      if (_newValidator == _validators[_count]) {
        _count++;
        continue;
      }

      delete _validatorMap[_validators[_count]];
      _validatorMap[_newValidator] = EnumFlags.ValidatorFlag.Both;
      _validators[_count] = _newValidator;
      _count++;
    }

    validatorCount = _count;
    emit ValidatorSetUpdated(_newPeriod, _newValidators);
  }

  /**
   * @dev Activate/Deactivate the validators from producing blocks, based on their in jail status and maintenance status.
   *
   * Requirements:
   * - This method is called at the end of each epoch
   *
   * Emits the `BlockProducerSetUpdated` event.
   *
   */
  function _revampBlockProducers(uint256 _newPeriod, address[] memory _currentValidators) private {
    bool[] memory _maintainedList = _maintenanceContract.checkManyMaintained(_candidates, block.number + 1);

    for (uint _i = 0; _i < _currentValidators.length; _i++) {
      address _currentValidator = _currentValidators[_i];
      bool _isProducerBefore = isBlockProducer(_currentValidator);
      bool _isProducerAfter = !(_jailed(_currentValidator) || _maintainedList[_i]);

      if (!_isProducerBefore && _isProducerAfter) {
        _validatorMap[_currentValidator] = _validatorMap[_currentValidator].addFlag(
          EnumFlags.ValidatorFlag.BlockProducer
        );
        continue;
      }

      if (_isProducerBefore && !_isProducerAfter) {
        _validatorMap[_currentValidator] = _validatorMap[_currentValidator].removeFlag(
          EnumFlags.ValidatorFlag.BlockProducer
        );
      }
    }

    emit BlockProducerSetUpdated(_newPeriod, getBlockProducers());
  }

  /**
   * @dev Override `ValidatorInfoStorage-_bridgeOperatorOf`.
   */
  function _bridgeOperatorOf(address _consensusAddr)
    internal
    view
    virtual
    override(CandidateManager, ValidatorInfoStorage)
    returns (address)
  {
    return CandidateManager._bridgeOperatorOf(_consensusAddr);
  }
}
