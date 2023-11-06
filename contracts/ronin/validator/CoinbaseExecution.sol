// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/collections/HasContracts.sol";
import "../../extensions/RONTransferHelper.sol";
import "../../interfaces/IProfile.sol";
import "../../interfaces/IStakingVesting.sol";
import "../../interfaces/IMaintenance.sol";
import "../../interfaces/IRoninTrustedOrganization.sol";
import "../../interfaces/IFastFinalityTracking.sol";
import "../../interfaces/staking/IStaking.sol";
import "../../interfaces/slash-indicator/ISlashIndicator.sol";
import "../../interfaces/validator/ICoinbaseExecution.sol";
import "../../libraries/EnumFlags.sol";
import "../../libraries/Math.sol";
import { HasStakingVestingDeprecated, HasBridgeTrackingDeprecated, HasMaintenanceDeprecated, HasSlashIndicatorDeprecated } from "../../utils/DeprecatedSlots.sol";
import "../../precompile-usages/PCUSortValidators.sol";
import "../../precompile-usages/PCUPickValidatorSet.sol";
import "./storage-fragments/CommonStorage.sol";
import { EmergencyExit } from "./EmergencyExit.sol";
import { TPoolId } from "../../udvts/Types.sol";
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
    address id = __css2cid(TConsensus.wrap(msg.sender));

    bool requestForBlockProducer = _isBlockProducerById(id) &&
      !_isJailedById(id) &&
      !_miningRewardDeprecatedById(id, currentPeriod());

    (, uint256 blockProducerBonus, , uint256 fastFinalityRewardPercentage) = IStakingVesting(
      getContract(ContractType.STAKING_VESTING)
    ).requestBonus({ forBlockProducer: requestForBlockProducer, forBridgeOperator: false });

    // Deprecates reward for non-validator or slashed validator
    if (!requestForBlockProducer) {
      _totalDeprecatedReward += msg.value;
      emit BlockRewardDeprecated(id, msg.value, BlockRewardDeprecatedType.UNAVAILABILITY);
      return;
    }

    emit BlockRewardSubmitted(id, msg.value, blockProducerBonus);

    uint256 period = currentPeriod();
    uint256 reward = msg.value + blockProducerBonus;
    uint256 rewardFastFinality = (reward * fastFinalityRewardPercentage) / _MAX_PERCENTAGE; // reward for fast finality
    uint256 rewardProducingBlock = reward - rewardFastFinality; // reward for producing blocks
    uint256 cutOffReward;

    // Add fast finality reward to total reward for current epoch, then split it later in the {wrapUpEpoch} method.
    _totalFastFinalityReward += rewardFastFinality;

    if (_miningRewardBailoutCutOffAtPeriod[msg.sender][period]) {
      (, , , uint256 cutOffPercentage) = ISlashIndicator(getContract(ContractType.SLASH_INDICATOR))
        .getCreditScoreConfigs();
      cutOffReward = (rewardProducingBlock * cutOffPercentage) / _MAX_PERCENTAGE;
      _totalDeprecatedReward += cutOffReward;
      emit BlockRewardDeprecated(id, cutOffReward, BlockRewardDeprecatedType.AFTER_BAILOUT);
    }

    rewardProducingBlock -= cutOffReward;
    (uint256 minRate, uint256 maxRate) = IStaking(getContract(ContractType.STAKING)).getCommissionRateRange();
    uint256 rate = Math.max(Math.min(_candidateInfo[id].commissionRate, maxRate), minRate);
    uint256 miningAmount = (rate * rewardProducingBlock) / _MAX_PERCENTAGE;
    _miningReward[id] += miningAmount;
    _delegatingReward[id] += (rewardProducingBlock - miningAmount);
  }

  /**
   * @inheritdoc ICoinbaseExecution
   */
  function wrapUpEpoch() external payable virtual override onlyCoinbase whenEpochEnding oncePerEpoch {
    uint256 newPeriod = _computePeriod(block.timestamp);
    bool periodEnding = _isPeriodEnding(newPeriod);

    address[] memory currValidatorIds = getValidators();
    address[] memory revokedCandidateIds;
    uint256 epoch = epochOf(block.number);
    uint256 nextEpoch = epoch + 1;
    uint256 lastPeriod = currentPeriod();

    _syncFastFinalityReward(epoch, currValidatorIds);

    if (periodEnding) {
      (
        uint256 totalDelegatingReward,
        uint256[] memory delegatingRewards
      ) = _distributeRewardToTreasuriesAndCalculateTotalDelegatingReward(lastPeriod, currValidatorIds);
      _settleAndTransferDelegatingRewards(lastPeriod, currValidatorIds, totalDelegatingReward, delegatingRewards);
      _tryRecycleLockedFundsFromEmergencyExits();
      _recycleDeprecatedRewards();

      ISlashIndicator slashIndicatorContract = ISlashIndicator(getContract(ContractType.SLASH_INDICATOR));
      slashIndicatorContract.execUpdateCreditScores(currValidatorIds, lastPeriod);
      (currValidatorIds, revokedCandidateIds) = _syncValidatorSet(newPeriod);
      if (revokedCandidateIds.length > 0) {
        slashIndicatorContract.execResetCreditScores(revokedCandidateIds);
      }
      _currentPeriodStartAtBlock = block.number + 1;
    }
    _revampRoles(newPeriod, nextEpoch, currValidatorIds);
    emit WrappedUpEpoch(lastPeriod, epoch, periodEnding);
    _periodOf[nextEpoch] = newPeriod;
    _lastUpdatedPeriod = newPeriod;
  }

  /**
   * @dev This method calculate and update reward of each `validators` accordingly their fast finality voting performance
   * in the `epoch`. The leftover reward is added to the {_totalDeprecatedReward} and is recycled later to the
   * {StakingVesting} contract.
   *
   * Requirements:
   * - This method is only called once each epoch.
   */
  function _syncFastFinalityReward(uint256 epoch, address[] memory validatorIds) private {
    uint256[] memory voteCounts = IFastFinalityTracking(getContract(ContractType.FAST_FINALITY_TRACKING))
      .getManyFinalityVoteCounts(epoch, validatorIds);
    uint256 divisor = _numberOfBlocksInEpoch * validatorIds.length;
    uint256 iReward;
    uint256 totalReward = _totalFastFinalityReward;
    uint256 totalDispensedReward = 0;

    for (uint i; i < validatorIds.length; ) {
      iReward = (totalReward * voteCounts[i]) / divisor;
      _fastFinalityReward[validatorIds[i]] += iReward;
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
   * - Update the total deprecated reward if the two previous conditions do not satisfy.
   *
   * Note: This method should be called once in the end of each period.
   *
   */
  function _distributeRewardToTreasuriesAndCalculateTotalDelegatingReward(
    uint256 lastPeriod,
    address[] memory currValidatorIds
  ) private returns (uint256 totalDelegatingReward, uint256[] memory delegatingRewards) {
    address vId; // validator id
    address payable treasury;
    delegatingRewards = new uint256[](currValidatorIds.length);

    for (uint _i; _i < currValidatorIds.length; ) {
      vId = currValidatorIds[_i];
      treasury = _candidateInfo[vId].__shadowedTreasury;

      if (!_isJailedById(vId) && !_miningRewardDeprecatedById(vId, lastPeriod)) {
        totalDelegatingReward += _delegatingReward[vId];
        delegatingRewards[_i] = _delegatingReward[vId];
        _distributeMiningReward(vId, treasury);
        _distributeFastFinalityReward(vId, treasury);
      } else {
        _totalDeprecatedReward += _miningReward[vId] + _delegatingReward[vId] + _fastFinalityReward[vId];
      }

      delete _delegatingReward[vId];
      delete _miningReward[vId];
      delete _fastFinalityReward[vId];

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
  function _distributeMiningReward(address cid, address payable treasury) private {
    uint256 amount = _miningReward[cid];
    if (amount > 0) {
      if (_unsafeSendRONLimitGas(treasury, amount, DEFAULT_ADDITION_GAS)) {
        emit MiningRewardDistributed(cid, treasury, amount);
        return;
      }

      emit MiningRewardDistributionFailed(cid, treasury, amount, address(this).balance);
    }
  }

  function _distributeFastFinalityReward(address consensusAddr, address payable treasury) private {
    uint256 amount = _fastFinalityReward[consensusAddr];
    if (amount > 0) {
      if (_unsafeSendRONLimitGas(treasury, amount, DEFAULT_ADDITION_GAS)) {
        emit FastFinalityRewardDistributed(consensusAddr, treasury, amount);
        return;
      }

      emit FastFinalityRewardDistributionFailed(consensusAddr, treasury, amount, address(this).balance);
    }
  }

  /**
   * @dev Helper function to settle rewards for delegators of `currValidatorIds` at the end of each period,
   * then transfer the rewards from this contract to the staking contract, in order to finalize a period.
   *
   * Emits the `StakingRewardDistributed` once the reward is distributed successfully.
   * Emits the `StakingRewardDistributionFailed` once the contract fails to distribute reward.
   *
   * Note: This method should be called once in the end of each period.
   *
   */
  function _settleAndTransferDelegatingRewards(
    uint256 period,
    address[] memory currValidatorIds,
    uint256 totalDelegatingReward,
    uint256[] memory delegatingRewards
  ) private {
    IStaking _staking = IStaking(getContract(ContractType.STAKING));
    if (totalDelegatingReward > 0) {
      if (_unsafeSendRON(payable(address(_staking)), totalDelegatingReward)) {
        _staking.execRecordRewards(currValidatorIds, delegatingRewards, period);
        emit StakingRewardDistributed(totalDelegatingReward, currValidatorIds, delegatingRewards);
        return;
      }

      emit StakingRewardDistributionFailed(
        totalDelegatingReward,
        currValidatorIds,
        delegatingRewards,
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
    uint256 withdrawAmount = _totalDeprecatedReward;

    if (withdrawAmount != 0) {
      address withdrawTarget = getContract(ContractType.STAKING_VESTING);

      delete _totalDeprecatedReward;

      (bool _success, ) = withdrawTarget.call{ value: withdrawAmount }(
        abi.encodeWithSelector(IStakingVesting.receiveRON.selector)
      );

      if (_success) {
        emit DeprecatedRewardRecycled(withdrawTarget, withdrawAmount);
      } else {
        emit DeprecatedRewardRecycleFailed(withdrawTarget, withdrawAmount, address(this).balance);
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
    uint256 newPeriod
  ) private returns (address[] memory newValidatorIds, address[] memory unsatisfiedCandidates) {
    unsatisfiedCandidates = _syncCandidateSet(newPeriod);
    uint256[] memory weights = IStaking(getContract(ContractType.STAKING)).getManyStakingTotalsById(_candidateIds);
    uint256[] memory trustedWeights = IRoninTrustedOrganization(getContract(ContractType.RONIN_TRUSTED_ORGANIZATION))
      .getManyConsensusWeightsById(_candidateIds);
    uint256 newValidatorCount;
    (newValidatorIds, newValidatorCount) = _pcPickValidatorSet(
      _candidateIds,
      weights,
      trustedWeights,
      _maxValidatorNumber,
      _maxPrioritizedValidatorNumber
    );
    _setNewValidatorSet(newValidatorIds, newValidatorCount, newPeriod);
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
  function _revampRoles(uint256 _newPeriod, uint256 _nextEpoch, address[] memory currValidatorIds) private {
    bool[] memory _maintainedList = IMaintenance(getContract(ContractType.MAINTENANCE)).checkManyMaintainedById(
      currValidatorIds,
      block.number + 1
    );

    for (uint _i; _i < currValidatorIds.length; ) {
      address validatorId = currValidatorIds[_i];
      bool emergencyExitRequested = block.timestamp <= _emergencyExitJailedTimestamp[validatorId];
      bool isProducerBefore = _isBlockProducerById(validatorId);
      bool isProducerAfter = !(_isJailedAtBlockById(validatorId, block.number + 1) ||
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
  function _isTrustedOrg(address validatorId) internal view override returns (bool) {
    return
      IRoninTrustedOrganization(getContract(ContractType.RONIN_TRUSTED_ORGANIZATION)).getConsensusWeightById(
        validatorId
      ) > 0;
  }
}
