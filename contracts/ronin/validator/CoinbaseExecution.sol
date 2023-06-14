// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/collections/HasContracts.sol";
import "../../extensions/RONTransferHelper.sol";
import "../../interfaces/IProfile.sol";
import "../../interfaces/IStakingVesting.sol";
import "../../interfaces/IMaintenance.sol";
import "../../interfaces/IBridgeTracking.sol";
import "../../interfaces/IRoninTrustedOrganization.sol";
import "../../interfaces/slash-indicator/ISlashIndicator.sol";
import "../../interfaces/validator/ICoinbaseExecution.sol";
import "../../libraries/EnumFlags.sol";
import "../../libraries/Math.sol";
import { HasStakingVestingDeprecated, HasBridgeTrackingDeprecated, HasMaintenanceDeprecated, HasSlashIndicatorDeprecated } from "../../utils/DeprecatedSlots.sol";
import "../../precompile-usages/PCUSortValidators.sol";
import "../../precompile-usages/PCUPickValidatorSet.sol";
import "./storage-fragments/CommonStorage.sol";
import "./CandidateManager.sol";
import "./EmergencyExit.sol";
import { TPoolId } from "../../libraries/udvts/Types.sol";

abstract contract CoinbaseExecution is
  ICoinbaseExecution,
  RONTransferHelper,
  PCUSortValidators,
  PCUPickValidatorSet,
  HasContracts,
  HasStakingVestingDeprecated,
  HasBridgeTrackingDeprecated,
  HasMaintenanceDeprecated,
  HasSlashIndicatorDeprecated,
  EmergencyExit
{
  using EnumFlags for EnumFlags.ValidatorFlag;

  modifier onlyCoinbase() {
    _requireCoinbase();
    _;
  }

  modifier whenEpochEnding() {
    if (!epochEndingAt(block.number)) revert ErrAtEndOfEpochOnly();
    _;
  }

  modifier oncePerEpoch() {
    if (epochOf(_lastUpdatedBlock) >= epochOf(block.number)) revert ErrAlreadyWrappedEpoch();
    _lastUpdatedBlock = block.number;
    _;
  }

  function _requireCoinbase() private view {
    if (msg.sender != block.coinbase) revert ErrCallerMustBeCoinbase();
  }

  /**
   * @inheritdoc ICoinbaseExecution
   */
  function submitBlockReward() external payable override onlyCoinbase {
    IProfile profileContract = IProfile(getContract(ContractType.PROFILE));
    address _correspondingPool = TPoolId.unwrap(profileContract.getConsensus2Id(msg.sender));
    bool _requestForBlockProducer = isBlockProducer(msg.sender) &&
      !_jailed(_correspondingPool) &&
      !_miningRewardDeprecated(_correspondingPool, currentPeriod());

    (, uint256 _blockProducerBonus, uint256 _bridgeOperatorBonus) = IStakingVesting(
      getContract(ContractType.STAKING_VESTING)
    ).requestBonus({ _forBlockProducer: _requestForBlockProducer, _forBridgeOperator: true });

    _totalBridgeReward += _bridgeOperatorBonus;

    // Deprecates reward for non-validator or slashed validator
    if (!_requestForBlockProducer) {
      _totalDeprecatedReward += msg.value;
      emit BlockRewardDeprecated(_correspondingPool, msg.value, BlockRewardDeprecatedType.UNAVAILABILITY);
      return;
    }

    emit BlockRewardSubmitted(_correspondingPool, msg.value, _blockProducerBonus);

    uint256 _period = currentPeriod();
    uint256 _reward = msg.value + _blockProducerBonus;
    uint256 _cutOffReward;
    if (_miningRewardBailoutCutOffAtPeriod[msg.sender][_period]) {
      (, , , uint256 _cutOffPercentage) = ISlashIndicator(getContract(ContractType.SLASH_INDICATOR))
        .getCreditScoreConfigs();
      _cutOffReward = (_reward * _cutOffPercentage) / _MAX_PERCENTAGE;
      _totalDeprecatedReward += _cutOffReward;
      emit BlockRewardDeprecated(_correspondingPool, _cutOffReward, BlockRewardDeprecatedType.AFTER_BAILOUT);
    }

    _reward -= _cutOffReward;
    (uint256 _minRate, uint256 _maxRate) = IStaking(getContract(ContractType.STAKING)).getCommissionRateRange();
    uint256 _rate = Math.max(Math.min(_candidateInfo[msg.sender].commissionRate, _maxRate), _minRate);
    uint256 _miningAmount = (_rate * _reward) / _MAX_PERCENTAGE;
    _miningReward[_correspondingPool] += _miningAmount;

    uint256 _delegatingAmount = _reward - _miningAmount;
    _delegatingReward[_correspondingPool] += _delegatingAmount;
  }

  /**
   * @inheritdoc ICoinbaseExecution
   */
  function wrapUpEpoch() external payable virtual override onlyCoinbase whenEpochEnding oncePerEpoch {
    uint256 _newPeriod = _computePeriod(block.timestamp);
    bool _periodEnding = _isPeriodEnding(_newPeriod);

    (address[] memory _currentValidators, , ) = getValidators();
    address[] memory _revokedCandidates;
    uint256 _epoch = epochOf(block.number);
    uint256 _nextEpoch = _epoch + 1;
    uint256 _lastPeriod = currentPeriod();

    if (_periodEnding) {
      _syncBridgeOperatingReward(_lastPeriod);
      (
        uint256 _totalDelegatingReward,
        uint256[] memory _delegatingRewards
      ) = _distributeRewardToTreasuriesAndCalculateTotalDelegatingReward(_lastPeriod, _currentValidators);
      _settleAndTransferDelegatingRewards(_lastPeriod, _currentValidators, _totalDelegatingReward, _delegatingRewards);
      _tryRecycleLockedFundsFromEmergencyExits();
      _recycleDeprecatedRewards();
      ISlashIndicator _slashIndicatorContract = ISlashIndicator(getContract(ContractType.SLASH_INDICATOR));
      _slashIndicatorContract.updateCreditScores(_currentValidators, _lastPeriod);
      (_currentValidators, _revokedCandidates) = _syncValidatorSet(_newPeriod);
      if (_revokedCandidates.length > 0) {
        _slashIndicatorContract.execResetCreditScores(_revokedCandidates);
      }
      _currentPeriodStartAtBlock = block.number + 1;
    }
    _revampRoles(_newPeriod, _nextEpoch, _currentValidators);
    emit WrappedUpEpoch(_lastPeriod, _epoch, _periodEnding);
    _periodOf[_nextEpoch] = _newPeriod;
    _lastUpdatedPeriod = _newPeriod;
  }

  /**
   * @dev This loop over the all current validators to sync the bridge operating reward.
   *
   * Note: This method should be called once in the end of each period.
   *
   */
  function _syncBridgeOperatingReward(uint256 _lastPeriod) internal {
    IBridgeTracking _bridgeTrackingContract = IBridgeTracking(getContract(ContractType.BRIDGE_TRACKING));
    uint256 _totalBridgeBallots = _bridgeTrackingContract.totalBallots(_lastPeriod);
    uint256 _totalBridgeVotes = _bridgeTrackingContract.totalVotes(_lastPeriod);

    (
      address[] memory _currentWorkingBridgeOperators,
      address[] memory _currentValidatorsOperatingBridge
    ) = getBridgeOperators();

    uint256[] memory _bridgeBallots = _bridgeTrackingContract.getManyTotalBallots(
      _lastPeriod,
      _currentWorkingBridgeOperators
    );

    if (
      !_validateBridgeTrackingResponse(_totalBridgeBallots, _totalBridgeVotes, _bridgeBallots) || _totalBridgeVotes == 0
    ) {
      // Shares equally in case the bridge has nothing to vote or bridge tracking response is incorrect
      for (uint256 _i; _i < _currentValidatorsOperatingBridge.length; ) {
        _bridgeOperatingReward[_currentValidatorsOperatingBridge[_i]] =
          _totalBridgeReward /
          _currentValidatorsOperatingBridge.length;

        unchecked {
          ++_i;
        }
      }
      return;
    }

    (
      uint256 _missingVotesRatioTier1,
      uint256 _missingVotesRatioTier2,
      uint256 _jailDurationForMissingVotesRatioTier2,
      uint256 _skipBridgeOperatorSlashingThreshold
    ) = ISlashIndicator(getContract(ContractType.SLASH_INDICATOR)).getBridgeOperatorSlashingConfigs();

    // Slashes the bridge reward if the total of votes exceeds the slashing threshold.
    bool _shouldSlash = _totalBridgeVotes > _skipBridgeOperatorSlashingThreshold;
    for (uint256 _i; _i < _currentValidatorsOperatingBridge.length; ) {
      // Shares the bridge operators reward proportionally.
      _bridgeOperatingReward[_currentValidatorsOperatingBridge[_i]] =
        (_totalBridgeReward * _bridgeBallots[_i]) /
        _totalBridgeBallots;
      if (_shouldSlash) {
        _slashBridgeOperatorBasedOnPerformance(
          _lastPeriod,
          _currentValidatorsOperatingBridge[_i],
          _MAX_PERCENTAGE - (_bridgeBallots[_i] * _MAX_PERCENTAGE) / _totalBridgeVotes,
          _jailDurationForMissingVotesRatioTier2,
          _missingVotesRatioTier1,
          _missingVotesRatioTier2
        );
      }

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @dev Returns whether the responses from bridge tracking are correct.
   */
  function _validateBridgeTrackingResponse(
    uint256 _totalBridgeBallots,
    uint256 _totalBridgeVotes,
    uint256[] memory _bridgeBallots
  ) private returns (bool _valid) {
    _valid = true;
    uint256 _sumBallots;
    for (uint _i; _i < _bridgeBallots.length; ) {
      if (_bridgeBallots[_i] > _totalBridgeVotes) {
        _valid = false;
        break;
      }
      _sumBallots += _bridgeBallots[_i];

      unchecked {
        ++_i;
      }
    }
    _valid = _valid && (_sumBallots <= _totalBridgeBallots);
    if (!_valid) {
      emit BridgeTrackingIncorrectlyResponded();
    }
  }

  /**
   * @dev Slashes the validator on the corresponding bridge operator performance. Updates the status of the deprecated reward. Not update the reward amount.
   *
   * Consider validating the bridge tracking response by using the method `_validateBridgeTrackingResponse` before calling this function.
   */
  function _slashBridgeOperatorBasedOnPerformance(
    uint256 _period,
    address _validator,
    uint256 _missedRatio,
    uint256 _jailDurationTier2,
    uint256 _ratioTier1,
    uint256 _ratioTier2
  ) internal {
    ISlashIndicator _slashIndicatorContract = ISlashIndicator(getContract(ContractType.SLASH_INDICATOR));
    if (_missedRatio >= _ratioTier2) {
      _bridgeRewardDeprecatedAtPeriod[_validator][_period] = true;
      _miningRewardDeprecatedAtPeriod[_validator][_period] = true;

      uint256 _newJailUntilBlock = Math.addIfNonZero(block.number, _jailDurationTier2);
      _blockProducerJailedBlock[_validator] = Math.max(_newJailUntilBlock, _blockProducerJailedBlock[_validator]);
      _cannotBailoutUntilBlock[_validator] = Math.max(_newJailUntilBlock, _cannotBailoutUntilBlock[_validator]);

      _slashIndicatorContract.execSlashBridgeOperator(_validator, 2, _period);
      emit ValidatorPunished(_validator, _period, _blockProducerJailedBlock[_validator], 0, true, true);
    } else if (_missedRatio >= _ratioTier1) {
      _bridgeRewardDeprecatedAtPeriod[_validator][_period] = true;
      _slashIndicatorContract.execSlashBridgeOperator(_validator, 1, _period);
      emit ValidatorPunished(_validator, _period, _blockProducerJailedBlock[_validator], 0, false, true);
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
    for (uint _i; _i < _currentValidators.length; ) {
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

      unchecked {
        ++_i;
      }
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
      if (_unsafeSendRON(_treasury, _amount, DEFAULT_ADDITION_GAS)) {
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
      if (_unsafeSendRON(_treasury, _amount, DEFAULT_ADDITION_GAS)) {
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
    IStaking _staking = IStaking(getContract(ContractType.STAKING));
    if (_totalDelegatingReward > 0) {
      if (_unsafeSendRON(payable(address(_staking)), _totalDelegatingReward)) {
        _staking.execRecordRewards(_currentValidators, _delegatingRewards, _period);
        emit StakingRewardDistributed(_totalDelegatingReward, _currentValidators, _delegatingRewards);
        return;
      }

      emit StakingRewardDistributionFailed(
        _totalDelegatingReward,
        _currentValidators,
        _delegatingRewards,
        address(this).balance
      );
    }
  }

  /**
   * @dev Transfer the deprecated rewards e.g. the rewards that get deprecated when validator is slashed/maintained,
   * to the staking vesting contract
   *
   * Note: This method should be called once in the end of each period.
   */
  function _recycleDeprecatedRewards() private {
    uint256 _withdrawAmount = _totalDeprecatedReward;

    if (_withdrawAmount != 0) {
      address _withdrawTarget = getContract(ContractType.STAKING_VESTING);

      delete _totalDeprecatedReward;

      (bool _success, ) = _withdrawTarget.call{ value: _withdrawAmount }(
        abi.encodeWithSelector(IStakingVesting.receiveRON.selector)
      );

      if (_success) {
        emit DeprecatedRewardRecycled(_withdrawTarget, _withdrawAmount);
      } else {
        emit DeprecatedRewardRecycleFailed(_withdrawTarget, _withdrawAmount, address(this).balance);
      }
    }
  }

  /**
   * @dev Updates the validator set based on the validator candidates from the Staking contract.
   *
   * Emits the `ValidatorSetUpdated` event.
   *
   * Note: This method should be called once in the end of each period.
   *
   */
  function _syncValidatorSet(
    uint256 _newPeriod
  ) private returns (address[] memory _newValidators, address[] memory _unsastifiedCandidates) {
    _unsastifiedCandidates = _syncCandidateSet(_newPeriod);
    uint256[] memory _weights = IStaking(getContract(ContractType.STAKING)).getManyStakingTotals(_candidates);
    uint256[] memory _trustedWeights = IRoninTrustedOrganization(getContract(ContractType.RONIN_TRUSTED_ORGANIZATION))
      .getConsensusWeights(_candidates);
    uint256 _newValidatorCount;
    (_newValidators, _newValidatorCount) = _pcPickValidatorSet(
      _candidates,
      _weights,
      _trustedWeights,
      _maxValidatorNumber,
      _maxPrioritizedValidatorNumber
    );
    _setNewValidatorSet(_newValidators, _newValidatorCount, _newPeriod);
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
    // Remove exceeding validators in the current set
    for (uint256 _i = _newValidatorCount; _i < validatorCount; ) {
      delete _validatorMap[_validators[_i]];
      delete _validators[_i];

      unchecked {
        ++_i;
      }
    }

    // Remove flag for all validator in the current set
    for (uint _i; _i < _newValidatorCount; ) {
      delete _validatorMap[_validators[_i]];

      unchecked {
        ++_i;
      }
    }

    // Update new validator set and set flag correspondingly.
    for (uint256 _i; _i < _newValidatorCount; ) {
      address _newValidator = _newValidators[_i];
      _validatorMap[_newValidator] = EnumFlags.ValidatorFlag.Both;
      _validators[_i] = _newValidator;

      unchecked {
        ++_i;
      }
    }

    validatorCount = _newValidatorCount;
    emit ValidatorSetUpdated(_newPeriod, _newValidators);
  }

  /**
   * @dev Activate/Deactivate the validators from producing blocks, based on their in jail status and maintenance status.
   *
   * Requirements:
   * - This method is called at the end of each epoch
   *
   * Emits the `BlockProducerSetUpdated` event.
   * Emits the `BridgeOperatorSetUpdated` event.
   *
   */
  function _revampRoles(uint256 _newPeriod, uint256 _nextEpoch, address[] memory _currentValidators) private {
    bool[] memory _maintainedList = IMaintenance(getContract(ContractType.MAINTENANCE)).checkManyMaintained(
      _currentValidators,
      block.number + 1
    );

    for (uint _i; _i < _currentValidators.length; ) {
      address _validator = _currentValidators[_i];
      bool _emergencyExitRequested = block.timestamp <= _emergencyExitJailedTimestamp[_validator];
      bool _isProducerBefore = isBlockProducer(_validator);
      bool _isProducerAfter = !(_jailedAtBlock(_validator, block.number + 1) ||
        _maintainedList[_i] ||
        _emergencyExitRequested);

      if (!_isProducerBefore && _isProducerAfter) {
        _validatorMap[_validator] = _validatorMap[_validator].addFlag(EnumFlags.ValidatorFlag.BlockProducer);
      } else if (_isProducerBefore && !_isProducerAfter) {
        _validatorMap[_validator] = _validatorMap[_validator].removeFlag(EnumFlags.ValidatorFlag.BlockProducer);
      }

      bool _isBridgeOperatorBefore = isOperatingBridge(_validator);
      bool _isBridgeOperatorAfter = !_emergencyExitRequested;
      if (!_isBridgeOperatorBefore && _isBridgeOperatorAfter) {
        _validatorMap[_validator] = _validatorMap[_validator].addFlag(EnumFlags.ValidatorFlag.BridgeOperator);
      } else if (_isBridgeOperatorBefore && !_isBridgeOperatorAfter) {
        _validatorMap[_validator] = _validatorMap[_validator].removeFlag(EnumFlags.ValidatorFlag.BridgeOperator);
      }

      unchecked {
        ++_i;
      }
    }

    (address[] memory _bridgeOperators, ) = getBridgeOperators();
    emit BlockProducerSetUpdated(_newPeriod, _nextEpoch, getBlockProducers());
    emit BridgeOperatorSetUpdated(_newPeriod, _nextEpoch, _bridgeOperators);
  }

  /**
   * @dev Override `CandidateManager-_isTrustedOrg`.
   */
  function _isTrustedOrg(address _consensusAddr) internal view override returns (bool) {
    return
      IRoninTrustedOrganization(getContract(ContractType.RONIN_TRUSTED_ORGANIZATION)).getConsensusWeight(
        _consensusAddr
      ) > 0;
  }
}
