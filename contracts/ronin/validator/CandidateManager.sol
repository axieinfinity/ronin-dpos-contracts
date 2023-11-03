// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/collections/HasContracts.sol";
import "../../extensions/consumers/GlobalConfigConsumer.sol";
import "../../extensions/consumers/PercentageConsumer.sol";
import "../../interfaces/validator/ICandidateManager.sol";
import "../../interfaces/staking/IStaking.sol";
import "../../interfaces/IProfile.sol";
import { HasStakingDeprecated } from "../../utils/DeprecatedSlots.sol";

abstract contract CandidateManager is
  ICandidateManager,
  PercentageConsumer,
  GlobalConfigConsumer,
  HasContracts,
  HasStakingDeprecated
{
  /// @dev Maximum number of validator candidate
  uint256 private _maxValidatorCandidate;

  /// @dev The array of candidate ids
  address[] internal _candidateIds;
  /// @dev Mapping from candidate id => bitwise negation of validator index in `_candidates`
  mapping(address => uint256) internal _candidateIndex;
  /// @dev Mapping from candidate id => their info
  mapping(address => ValidatorCandidate) internal _candidateInfo;

  /**
   * @dev The minimum offset in day from current date to the effective date of a new commission schedule.
   * Value of 1 means the change gets affected at the beginning of the following day.
   **/
  uint256 internal _minEffectiveDaysOnwards;
  /// @dev Mapping from candidate consensus id => schedule commission change.
  mapping(address => CommissionSchedule) internal _candidateCommissionChangeSchedule;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[48] private ______gap;

  /**
   * @inheritdoc ICandidateManager
   */
  function maxValidatorCandidate() public view override returns (uint256) {
    return _maxValidatorCandidate;
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function minEffectiveDaysOnward() external view override returns (uint256) {
    return _minEffectiveDaysOnwards;
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function setMaxValidatorCandidate(uint256 _number) external override onlyAdmin {
    _setMaxValidatorCandidate(_number);
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function setMinEffectiveDaysOnwards(uint256 _numOfDays) external override onlyAdmin {
    _setMinEffectiveDaysOnwards(_numOfDays);
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function execApplyValidatorCandidate(
    address candidateAdmin,
    address cid,
    address payable treasuryAddr,
    uint256 commissionRate
  ) external override onlyContract(ContractType.STAKING) {
    uint256 length = _candidateIds.length;
    if (length >= maxValidatorCandidate()) revert ErrExceedsMaxNumberOfCandidate();
    if (_isValidatorCandidateById(cid)) revert ErrExistentCandidate();
    if (commissionRate > _MAX_PERCENTAGE) revert ErrInvalidCommissionRate();

    for (uint i; i < length; ) {
      ValidatorCandidate storage existentInfo = _candidateInfo[_candidateIds[i]];
      if (candidateAdmin == existentInfo.__shadowedAdmin) revert ErrExistentCandidateAdmin(candidateAdmin);
      if (treasuryAddr == existentInfo.__shadowedTreasury) revert ErrExistentTreasury(treasuryAddr);

      unchecked {
        ++i;
      }
    }

    _candidateIndex[cid] = ~length;
    _candidateIds.push(cid);

    ValidatorCandidate storage _info = _candidateInfo[cid];
    _info.__shadowedAdmin = candidateAdmin;
    _info.__shadowedConsensus = TConsensus.wrap(cid);
    _info.__shadowedTreasury = treasuryAddr;
    _info.commissionRate = commissionRate;
    emit CandidateGranted(cid, treasuryAddr, candidateAdmin);
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function execRequestRenounceCandidate(
    address cid,
    uint256 secsLeft
  ) external override onlyContract(ContractType.STAKING) {
    if (_isTrustedOrg(cid)) revert ErrTrustedOrgCannotRenounce();

    ValidatorCandidate storage _info = _candidateInfo[cid];
    if (_info.revokingTimestamp != 0) revert ErrAlreadyRequestedRevokingCandidate();
    _setRevokingTimestamp(_info, block.timestamp + secsLeft);
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function execRequestUpdateCommissionRate(
    address cid,
    uint256 effectiveDaysOnwards,
    uint256 commissionRate
  ) external override onlyContract(ContractType.STAKING) {
    if (_candidateCommissionChangeSchedule[cid].effectiveTimestamp != 0) {
      revert ErrAlreadyRequestedUpdatingCommissionRate();
    }
    if (commissionRate > _MAX_PERCENTAGE) revert ErrInvalidCommissionRate();
    if (effectiveDaysOnwards < _minEffectiveDaysOnwards) revert ErrInvalidEffectiveDaysOnwards();

    CommissionSchedule storage _schedule = _candidateCommissionChangeSchedule[cid];
    uint256 effectiveTimestamp = ((block.timestamp / PERIOD_DURATION) + effectiveDaysOnwards) * PERIOD_DURATION;
    _schedule.effectiveTimestamp = effectiveTimestamp;
    _schedule.commissionRate = commissionRate;

    emit CommissionRateUpdateScheduled(cid, effectiveTimestamp, commissionRate);
  }

  function execChangeConsensusAddress(
    address cid,
    TConsensus newConsensusAddr
  ) external override onlyContract(ContractType.PROFILE) {
    // Sync Consensus Address mapping
    _candidateInfo[cid].__shadowedConsensus = newConsensusAddr;

    // TODO: Seem has been handled with
    // Sync Jail mapping
    // Sync Pending reward mapping
    // Sync Schedule mapping

    // TODO: Handle
    // Sync RoninTrustedOrg
  }

  function execChangeAdminAddress(address cid, address newAdmin) external onlyContract(ContractType.PROFILE) {
    _candidateInfo[cid].__shadowedAdmin = newAdmin;
  }

  function execChangeTreasuryAddress(
    address cid,
    address payable newTreasury
  ) external onlyContract(ContractType.PROFILE) {
    _candidateInfo[cid].__shadowedTreasury = newTreasury;
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function isValidatorCandidate(TConsensus consensus) external view override returns (bool) {
    return _isValidatorCandidateById(__css2cid(consensus));
  }

  function _isValidatorCandidateById(address cid) internal view returns (bool) {
    return _candidateIndex[cid] != 0;
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function getCandidateInfos() external view override returns (ValidatorCandidate[] memory list) {
    list = new ValidatorCandidate[](_candidateIds.length);
    for (uint i; i < list.length; ) {
      list[i] = _candidateInfo[_candidateIds[i]];

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function getCandidateInfo(TConsensus consensus) external view override returns (ValidatorCandidate memory) {
    address validatorId = __css2cid(consensus);
    if (!_isValidatorCandidateById(validatorId)) revert ErrNonExistentCandidate();
    return _candidateInfo[validatorId];
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function getValidatorCandidates() public view override returns (address[] memory) {
    return _candidateIds;
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function getCommissionChangeSchedule(
    TConsensus consensus
  ) external view override returns (CommissionSchedule memory) {
    return _candidateCommissionChangeSchedule[__css2cid(consensus)];
  }

  /**
   * @dev Removes unsastisfied candidates, the ones who have insufficient minimum candidate staking amount,
   * or the ones who requested to renounce their candidate role.
   *
   * Emits the event `CandidatesRevoked` when a candidate is revoked.
   *
   */
  function _syncCandidateSet(uint256 _nextPeriod) internal returns (address[] memory _unsatisfiedCandidates) {
    IStaking _staking = IStaking(getContract(ContractType.STAKING));
    uint256 _waitingSecsToRevoke = _staking.waitingSecsToRevoke();
    uint256 _minStakingAmount = _staking.minValidatorStakingAmount();
    uint256[] memory _selfStakings = _staking.getManySelfStakingsById(_candidateIds);

    uint256 _length = _candidateIds.length;
    uint256 _unsatisfiedCount;
    _unsatisfiedCandidates = new address[](_length);

    {
      uint256 _i;
      address cid;
      ValidatorCandidate storage _info;
      while (_i < _length) {
        cid = _candidateIds[_i];
        _info = _candidateInfo[cid];

        // Checks for under-balance status of candidates
        bool _hasTopupDeadline = _info.topupDeadline != 0;
        if (_selfStakings[_i] < _minStakingAmount) {
          // Updates deadline on the first time unsatisfied the staking amount condition
          if (!_hasTopupDeadline) {
            uint256 _topupDeadline = block.timestamp + _waitingSecsToRevoke;
            _info.topupDeadline = _topupDeadline;
            emit CandidateTopupDeadlineUpdated(cid, _topupDeadline);
          }
        } else if (_hasTopupDeadline) {
          // Removes the deadline if the staking amount condition is satisfied
          delete _info.topupDeadline;
          emit CandidateTopupDeadlineUpdated(cid, 0);
        }

        // Removes unsastisfied candidates
        bool _revokingActivated = (_info.revokingTimestamp != 0 && _info.revokingTimestamp <= block.timestamp) ||
          _emergencyExitLockedFundReleased(cid);
        bool _topupDeadlineMissed = _info.topupDeadline != 0 && _info.topupDeadline <= block.timestamp;
        if (_revokingActivated || _topupDeadlineMissed) {
          _selfStakings[_i] = _selfStakings[--_length];
          unchecked {
            _unsatisfiedCandidates[_unsatisfiedCount++] = cid;
          }
          _removeCandidate(cid);
          continue;
        }

        // Checks for schedule of commission change and updates commission rate
        uint256 _scheduleTimestamp = _candidateCommissionChangeSchedule[cid].effectiveTimestamp;
        if (_scheduleTimestamp != 0 && _scheduleTimestamp <= block.timestamp) {
          uint256 _commisionRate = _candidateCommissionChangeSchedule[cid].commissionRate;
          delete _candidateCommissionChangeSchedule[cid];
          _info.commissionRate = _commisionRate;
          emit CommissionRateUpdated(cid, _commisionRate);
        }

        unchecked {
          _i++;
        }
      }
    }

    assembly {
      mstore(_unsatisfiedCandidates, _unsatisfiedCount)
    }

    if (_unsatisfiedCount > 0) {
      emit CandidatesRevoked(_unsatisfiedCandidates);
      _staking.execDeprecatePools(_unsatisfiedCandidates, _nextPeriod);
    }
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function isCandidateAdmin(TConsensus consensusAddr, address admin) external view override returns (bool) {
    return _isCandidateAdminById(__css2cid(consensusAddr), admin);
  }

  function _isCandidateAdminById(address candidateId, address admin) internal view returns (bool) {
    return _candidateInfo[candidateId].__shadowedAdmin == admin;
  }

  /**
   * @dev Sets the maximum number of validator candidate.
   *
   * Emits the `MaxValidatorCandidateUpdated` event.
   *
   */
  function _setMaxValidatorCandidate(uint256 _threshold) internal {
    _maxValidatorCandidate = _threshold;
    emit MaxValidatorCandidateUpdated(_threshold);
  }

  /**
   * @dev Sets the minimum number of days onwards to the effective date of commission rate change.
   *
   * Emits the `MinEffectiveDaysOnwardsUpdated` event.
   *
   */
  function _setMinEffectiveDaysOnwards(uint256 _numOfDays) internal {
    if (_numOfDays < 1) revert ErrInvalidMinEffectiveDaysOnwards();
    _minEffectiveDaysOnwards = _numOfDays;
    emit MinEffectiveDaysOnwardsUpdated(_numOfDays);
  }

  /**
   * @dev Removes the candidate.
   */
  function _removeCandidate(address _addr) internal virtual {
    uint256 idx = _candidateIndex[_addr];
    if (idx == 0) {
      return;
    }

    delete _candidateInfo[_addr];
    delete _candidateIndex[_addr];
    delete _candidateCommissionChangeSchedule[_addr];

    address lastCid = _candidateIds[_candidateIds.length - 1];
    if (lastCid != _addr) {
      _candidateIndex[lastCid] = idx;
      _candidateIds[~idx] = lastCid;
    }

    _candidateIds.pop();
  }

  /**
   * @dev Sets timestamp to revoke a candidate.
   */
  function _setRevokingTimestamp(ValidatorCandidate storage _candidate, uint256 timestamp) internal {
    address cid = __css2cid(_candidate.__shadowedConsensus);
    if (!_isValidatorCandidateById(cid)) revert ErrNonExistentCandidate();
    _candidate.revokingTimestamp = timestamp;
    emit CandidateRevokingTimestampUpdated(cid, timestamp);
  }

  /**
   * @dev Returns a flag indicating whether the fund is unlocked.
   */
  function _emergencyExitLockedFundReleased(address _consensusAddr) internal virtual returns (bool);

  /**
   * @dev Returns whether the consensus address is a trusted org or not.
   */
  function _isTrustedOrg(address _consensusAddr) internal virtual returns (bool);

  function __css2cid(TConsensus consensusAddr) internal view virtual returns (address) {
    return IProfile(getContract(ContractType.PROFILE)).getConsensus2Id(consensusAddr);
  }

  function __css2cidBatch(TConsensus[] memory consensusAddrs) internal view virtual returns (address[] memory) {
    return IProfile(getContract(ContractType.PROFILE)).getManyConsensus2Id(consensusAddrs);
  }
}
