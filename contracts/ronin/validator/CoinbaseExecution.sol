// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/collections/HasContracts.sol";
import "../../extensions/RONTransferHelper.sol";
import "../../interfaces/IStakingVesting.sol";
import "../../interfaces/IMaintenance.sol";
import "../../interfaces/IRoninTrustedOrganization.sol";
import "../../interfaces/IFastFinalityTracking.sol";
import "../../interfaces/slash-indicator/ISlashIndicator.sol";
import "../../interfaces/validator/ICoinbaseExecution.sol";
import "../../libraries/EnumFlags.sol";
import "../../libraries/Math.sol";
import { HasStakingVestingDeprecated, HasBridgeTrackingDeprecated, HasMaintenanceDeprecated, HasSlashIndicatorDeprecated } from "../../utils/DeprecatedSlots.sol";
import "../../precompile-usages/PCUSortValidators.sol";
import "../../precompile-usages/PCUPickValidatorSet.sol";
import "./storage-fragments/CommonStorage.sol";
import "./CandidateManager.sol";
import { EmergencyExit } from "./EmergencyExit.sol";
import { ErrCallerMustBeCoinbase } from "../../utils/CommonErrors.sol";

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
    bool requestForBlockProducer = isBlockProducer(msg.sender) &&
      !_jailed(msg.sender) &&
      !_miningRewardDeprecated(msg.sender, currentPeriod());

    (, uint256 blockProducerBonus, , uint256 fastFinalityRewardPercentage) = IStakingVesting(
      getContract(ContractType.STAKING_VESTING)
    ).requestBonus({ forBlockProducer: requestForBlockProducer, forBridgeOperator: false });

    // Deprecates reward for non-validator or slashed validator
    if (!requestForBlockProducer) {
      _totalDeprecatedReward += msg.value;
      emit BlockRewardDeprecated(msg.sender, msg.value, BlockRewardDeprecatedType.UNAVAILABILITY);
      return;
    }

    emit BlockRewardSubmitted(msg.sender, msg.value, blockProducerBonus);

    uint256 period = currentPeriod();
    uint256 reward = msg.value + blockProducerBonus;
    uint256 rewardFastFinality = (reward * fastFinalityRewardPercentage) / _MAX_PERCENTAGE; // reward for fast finality
    uint256 rewardProducingBlock = reward - rewardFastFinality; // reward for producing blocks
    uint256 cutOffReward;

    // Add fast finality reward to total reward for current epoch, then split it later in the {wrapupEpoch} method.
    _totalFastFinalityReward += rewardFastFinality;

    if (_miningRewardBailoutCutOffAtPeriod[msg.sender][period]) {
      (, , , uint256 cutOffPercentage) = ISlashIndicator(getContract(ContractType.SLASH_INDICATOR))
        .getCreditScoreConfigs();
      cutOffReward = (rewardProducingBlock * cutOffPercentage) / _MAX_PERCENTAGE;
      _totalDeprecatedReward += cutOffReward;
      emit BlockRewardDeprecated(msg.sender, cutOffReward, BlockRewardDeprecatedType.AFTER_BAILOUT);
    }

    rewardProducingBlock -= cutOffReward;
    (uint256 minRate, uint256 maxRate) = IStaking(getContract(ContractType.STAKING)).getCommissionRateRange();
    uint256 rate = Math.max(Math.min(_candidateInfo[msg.sender].commissionRate, maxRate), minRate);
    uint256 miningAmount = (rate * rewardProducingBlock) / _MAX_PERCENTAGE;
    _miningReward[msg.sender] += miningAmount;

    uint256 delegatingAmount = rewardProducingBlock - miningAmount;
    _delegatingReward[msg.sender] += delegatingAmount;
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

    _syncFastFinalityReward(_epoch, _currentValidators);

    if (_periodEnding) {
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
   * @dev This method calculate and update reward of each `validators` accordingly thier fast finality voting performance
   * in the `epoch`. The leftover reward is added to the {_totalDeprecatedReward} and is recycled later to the
   * {StakingVesting} contract.
   *
   * Requirements:
   * - This method is only called once each epoch.
   */
  function _syncFastFinalityReward(uint256 epoch, address[] memory validators) private {
    uint256[] memory voteCounts = IFastFinalityTracking(getContract(ContractType.FAST_FINALITY_TRACKING))
      .getManyFinalityVoteCounts(epoch, validators);
    uint256 divisor = _numberOfBlocksInEpoch * validators.length;
    uint256 iReward;
    uint256 totalReward = _totalFastFinalityReward;
    uint256 totalDispensedReward = 0;

    for (uint i; i < validators.length; ) {
      iReward = (totalReward * voteCounts[i]) / divisor;
      _fastFinalityReward[validators[i]] += iReward;
      totalDispensedReward += iReward;
      unchecked {
        ++i;
      }
    }

    _totalDeprecatedReward += (totalReward - totalDispensedReward);
    delete _totalFastFinalityReward;
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

      if (!_jailed(_consensusAddr) && !_miningRewardDeprecated(_consensusAddr, _lastPeriod)) {
        _totalDelegatingReward += _delegatingReward[_consensusAddr];
        _delegatingRewards[_i] = _delegatingReward[_consensusAddr];
        _distributeMiningReward(_consensusAddr, _treasury);
        _distributeFastFinalityReward(_consensusAddr, _treasury);
      } else {
        _totalDeprecatedReward +=
          _miningReward[_consensusAddr] +
          _delegatingReward[_consensusAddr] +
          _fastFinalityReward[_consensusAddr];
      }

      delete _delegatingReward[_consensusAddr];
      delete _miningReward[_consensusAddr];
      delete _fastFinalityReward[_consensusAddr];

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
      if (_unsafeSendRONLimitGas(_treasury, _amount, DEFAULT_ADDITION_GAS)) {
        emit MiningRewardDistributed(_consensusAddr, _treasury, _amount);
        return;
      }

      emit MiningRewardDistributionFailed(_consensusAddr, _treasury, _amount, address(this).balance);
    }
  }

  function _distributeFastFinalityReward(address _consensusAddr, address payable _treasury) private {
    uint256 _amount = _fastFinalityReward[_consensusAddr];
    if (_amount > 0) {
      if (_unsafeSendRONLimitGas(_treasury, _amount, DEFAULT_ADDITION_GAS)) {
        emit FastFinalityRewardDistributed(_consensusAddr, _treasury, _amount);
        return;
      }

      emit FastFinalityRewardDistributionFailed(_consensusAddr, _treasury, _amount, address(this).balance);
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
