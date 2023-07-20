// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/collections/HasContracts.sol";
import "../../extensions/RONTransferHelper.sol";
import "../../interfaces/IProfile.sol";
import "../../interfaces/IStakingVesting.sol";
import "../../interfaces/IMaintenance.sol";
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
import { TPoolId } from "../../udvts/Types.sol";

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
    address id = _convertC2P(TConsensus.wrap(msg.sender));

    bool requestForBlockProducer = _isBlockProducerById(id) &&
      !_jailed(id) &&
      !_miningRewardDeprecatedById(id, currentPeriod());

    (, uint256 blockProducerBonus, ) = IStakingVesting(getContract(ContractType.STAKING_VESTING)).requestBonus({
      forBlockProducer: requestForBlockProducer,
      forBridgeOperator: false
    });

    // Deprecates reward for non-validator or slashed validator
    if (!requestForBlockProducer) {
      _totalDeprecatedReward += msg.value;
      emit BlockRewardDeprecated(id, msg.value, BlockRewardDeprecatedType.UNAVAILABILITY);
      return;
    }

    emit BlockRewardSubmitted(id, msg.value, blockProducerBonus);

    uint256 period = currentPeriod();
    uint256 reward = msg.value + blockProducerBonus;
    uint256 cutOffReward;
    if (_miningRewardBailoutCutOffAtPeriod[id][period]) {
      (, , , uint256 cutOffPercentage) = ISlashIndicator(getContract(ContractType.SLASH_INDICATOR))
        .getCreditScoreConfigs();
      cutOffReward = (reward * cutOffPercentage) / _MAX_PERCENTAGE;
      _totalDeprecatedReward += cutOffReward;
      emit BlockRewardDeprecated(id, cutOffReward, BlockRewardDeprecatedType.AFTER_BAILOUT);
    }

    reward -= cutOffReward;
    (uint256 minRate, uint256 maxRate) = IStaking(getContract(ContractType.STAKING)).getCommissionRateRange();
    uint256 rate = Math.max(Math.min(_candidateInfo[id].commissionRate, maxRate), minRate);
    uint256 miningAmount = (rate * reward) / _MAX_PERCENTAGE;
    _miningReward[id] += miningAmount;

    uint256 delegatingAmount = reward - miningAmount;
    _delegatingReward[id] += delegatingAmount;
  }

  /**
   * @inheritdoc ICoinbaseExecution
   */
  function wrapUpEpoch() external payable virtual override onlyCoinbase whenEpochEnding oncePerEpoch {
    uint256 _newPeriod = _computePeriod(block.timestamp);
    bool _periodEnding = _isPeriodEnding(_newPeriod);

    address[] memory _currentValidators = getValidators();
    address[] memory _revokedCandidates;
    uint256 _epoch = epochOf(block.number);
    uint256 _nextEpoch = _epoch + 1;
    uint256 _lastPeriod = currentPeriod();

    if (_periodEnding) {
      (
        uint256 _totalDelegatingReward,
        uint256[] memory _delegatingRewards
      ) = _distributeRewardToTreasuriesAndCalculateTotalDelegatingReward(_lastPeriod, _currentValidators);
      _settleAndTransferDelegatingRewards(_lastPeriod, _currentValidators, _totalDelegatingReward, _delegatingRewards);
      _tryRecycleLockedFundsFromEmergencyExits();
      _recycleDeprecatedRewards();
      ISlashIndicator _slashIndicatorContract = ISlashIndicator(getContract(ContractType.SLASH_INDICATOR));
      _slashIndicatorContract.execUpdateCreditScores(_currentValidators, _lastPeriod);
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

      if (!_jailed(_consensusAddr) && !_miningRewardDeprecatedById(_consensusAddr, _lastPeriod)) {
        _totalDelegatingReward += _delegatingReward[_consensusAddr];
        _delegatingRewards[_i] = _delegatingReward[_consensusAddr];
        _distributeMiningReward(_consensusAddr, _treasury);
      } else {
        _totalDeprecatedReward += _miningReward[_consensusAddr] + _delegatingReward[_consensusAddr];
      }

      delete _delegatingReward[_consensusAddr];
      delete _miningReward[_consensusAddr];

      unchecked {
        ++_i;
      }
    }
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
    uint256[] memory _weights = IStaking(getContract(ContractType.STAKING)).getManyStakingTotalsById(_candidates);
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
    for (uint256 _i = _newValidatorCount; _i < _validatorCount; ) {
      delete _validatorMap[_validatorIds[_i]];
      delete _validatorIds[_i];

      unchecked {
        ++_i;
      }
    }

    // Remove flag for all validator in the current set
    for (uint _i; _i < _newValidatorCount; ) {
      delete _validatorMap[_validatorIds[_i]];

      unchecked {
        ++_i;
      }
    }

    // Update new validator set and set flag correspondingly.
    for (uint256 _i; _i < _newValidatorCount; ) {
      address _newValidator = _newValidators[_i];
      _validatorMap[_newValidator] = EnumFlags.ValidatorFlag.Both;
      _validatorIds[_i] = _newValidator;

      unchecked {
        ++_i;
      }
    }

    _validatorCount = _newValidatorCount;
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
    bool[] memory _maintainedList = IMaintenance(getContract(ContractType.MAINTENANCE)).checkManyMaintainedById(
      _currentValidators,
      block.number + 1
    );

    for (uint _i; _i < _currentValidators.length; ) {
      address validatorId = _currentValidators[_i];
      bool emergencyExitRequested = block.timestamp <= _emergencyExitJailedTimestamp[validatorId];
      bool isProducerBefore = _isBlockProducerById(validatorId);
      bool isProducerAfter = !(_jailedAtBlock(validatorId, block.number + 1) ||
        _maintainedList[_i] ||
        emergencyExitRequested);

      if (!isProducerBefore && isProducerAfter) {
        _validatorMap[validatorId] = _validatorMap[validatorId].addFlag(EnumFlags.ValidatorFlag.BlockProducer);
      } else if (isProducerBefore && !isProducerAfter) {
        _validatorMap[validatorId] = _validatorMap[validatorId].removeFlag(EnumFlags.ValidatorFlag.BlockProducer);
      }

      unchecked {
        ++_i;
      }
    }
    emit BlockProducerSetUpdated(_newPeriod, _nextEpoch, getBlockProducers());
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
