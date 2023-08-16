// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/collections/HasContracts.sol";
import "../../extensions/consumers/GlobalConfigConsumer.sol";
import "../../extensions/consumers/PercentageConsumer.sol";
import "../../interfaces/validator/ICandidateManager.sol";
import "../../interfaces/staking/IStaking.sol";
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

  /// @dev The validator candidate array
  address[] internal _candidates;
  /// @dev Mapping from candidate consensus address => bitwise negation of validator index in `_candidates`
  mapping(address => uint256) internal _candidateIndex;
  /// @dev Mapping from candidate consensus address => their info
  mapping(address => ValidatorCandidate) internal _candidateInfo;

  /**
   * @dev The minimum offset in day from current date to the effective date of a new commission schedule.
   * Value of 1 means the change gets affected at the beginning of the following day.
   **/
  uint256 internal _minEffectiveDaysOnwards;
  /// @dev Mapping from candidate consensus address => schedule commission change.
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
    address _candidateAdmin,
    address _consensusAddr,
    address payable _treasuryAddr,
    uint256 _commissionRate
  ) external override onlyContract(ContractType.STAKING) {
    uint256 _length = _candidates.length;
    if (_length >= maxValidatorCandidate()) revert ErrExceedsMaxNumberOfCandidate();
    if (isValidatorCandidate(_consensusAddr)) revert ErrExistentCandidate();
    if (_commissionRate > _MAX_PERCENTAGE) revert ErrInvalidCommissionRate();

    for (uint _i; _i < _candidates.length; ) {
      ValidatorCandidate storage existentInfo = _candidateInfo[_candidates[_i]];
      if (_candidateAdmin == existentInfo.admin) revert ErrExistentCandidateAdmin(_candidateAdmin);
      if (_treasuryAddr == existentInfo.treasuryAddr) revert ErrExistentTreasury(_treasuryAddr);

      unchecked {
        ++_i;
      }
    }

    _candidateIndex[_consensusAddr] = ~_length;
    _candidates.push(_consensusAddr);

    ValidatorCandidate storage _info = _candidateInfo[_consensusAddr];
    _info.admin = _candidateAdmin;
    _info.consensusAddr = _consensusAddr;
    _info.treasuryAddr = _treasuryAddr;
    _info.commissionRate = _commissionRate;
    emit CandidateGranted(_consensusAddr, _treasuryAddr, _candidateAdmin);
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function execRequestRenounceCandidate(
    address _consensusAddr,
    uint256 _secsLeft
  ) external override onlyContract(ContractType.STAKING) {
    if (_isTrustedOrg(_consensusAddr)) revert ErrTrustedOrgCannotRenounce();

    ValidatorCandidate storage _info = _candidateInfo[_consensusAddr];
    if (_info.revokingTimestamp != 0) revert ErrAlreadyRequestedRevokingCandidate();
    _setRevokingTimestamp(_info, block.timestamp + _secsLeft);
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function execRequestUpdateCommissionRate(
    address _consensusAddr,
    uint256 _effectiveDaysOnwards,
    uint256 _commissionRate
  ) external override onlyContract(ContractType.STAKING) {
    if (_candidateCommissionChangeSchedule[_consensusAddr].effectiveTimestamp != 0) {
      revert ErrAlreadyRequestedUpdatingCommissionRate();
    }
    if (_commissionRate > _MAX_PERCENTAGE) revert ErrInvalidCommissionRate();
    if (_effectiveDaysOnwards < _minEffectiveDaysOnwards) revert ErrInvalidEffectiveDaysOnwards();

    CommissionSchedule storage _schedule = _candidateCommissionChangeSchedule[_consensusAddr];
    uint256 _effectiveTimestamp = ((block.timestamp / PERIOD_DURATION) + _effectiveDaysOnwards) * PERIOD_DURATION;
    _schedule.effectiveTimestamp = _effectiveTimestamp;
    _schedule.commissionRate = _commissionRate;

    emit CommissionRateUpdateScheduled(_consensusAddr, _effectiveTimestamp, _commissionRate);
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function isValidatorCandidate(address _addr) public view override returns (bool) {
    return _candidateIndex[_addr] != 0;
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function getCandidateInfos() external view override returns (ValidatorCandidate[] memory _list) {
    _list = new ValidatorCandidate[](_candidates.length);
    for (uint _i; _i < _list.length; ) {
      _list[_i] = _candidateInfo[_candidates[_i]];

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function getCandidateInfo(address _candidate) external view override returns (ValidatorCandidate memory) {
    if (!isValidatorCandidate(_candidate)) revert ErrNonExistentCandidate();
    return _candidateInfo[_candidate];
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function getValidatorCandidates() public view override returns (address[] memory) {
    return _candidates;
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function getCommissionChangeSchedule(address _candidate) external view override returns (CommissionSchedule memory) {
    return _candidateCommissionChangeSchedule[_candidate];
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
    uint256[] memory _selfStakings = _staking.getManySelfStakings(_candidates);

    uint256 _length = _candidates.length;
    uint256 _unsatisfiedCount;
    _unsatisfiedCandidates = new address[](_length);

    {
      uint256 _i;
      address _addr;
      ValidatorCandidate storage _info;
      while (_i < _length) {
        _addr = _candidates[_i];
        _info = _candidateInfo[_addr];

        // Checks for under-balance status of candidates
        bool _hasTopupDeadline = _info.topupDeadline != 0;
        if (_selfStakings[_i] < _minStakingAmount) {
          // Updates deadline on the first time unsatisfied the staking amount condition
          if (!_hasTopupDeadline) {
            uint256 _topupDeadline = block.timestamp + _waitingSecsToRevoke;
            _info.topupDeadline = _topupDeadline;
            emit CandidateTopupDeadlineUpdated(_addr, _topupDeadline);
          }
        } else if (_hasTopupDeadline) {
          // Removes the deadline if the staking amount condition is satisfied
          delete _info.topupDeadline;
          emit CandidateTopupDeadlineUpdated(_addr, 0);
        }

        // Removes unsastisfied candidates
        bool _revokingActivated = (_info.revokingTimestamp != 0 && _info.revokingTimestamp <= block.timestamp) ||
          _emergencyExitLockedFundReleased(_addr);
        bool _topupDeadlineMissed = _info.topupDeadline != 0 && _info.topupDeadline <= block.timestamp;
        if (_revokingActivated || _topupDeadlineMissed) {
          _selfStakings[_i] = _selfStakings[--_length];
          unchecked {
            _unsatisfiedCandidates[_unsatisfiedCount++] = _addr;
          }
          _removeCandidate(_addr);
          continue;
        }

        // Checks for schedule of commission change and updates commission rate
        uint256 _scheduleTimestamp = _candidateCommissionChangeSchedule[_addr].effectiveTimestamp;
        if (_scheduleTimestamp != 0 && _scheduleTimestamp <= block.timestamp) {
          uint256 _commisionRate = _candidateCommissionChangeSchedule[_addr].commissionRate;
          delete _candidateCommissionChangeSchedule[_addr];
          _info.commissionRate = _commisionRate;
          emit CommissionRateUpdated(_addr, _commisionRate);
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
  function isCandidateAdmin(address _candidate, address _admin) external view override returns (bool) {
    return _candidateInfo[_candidate].admin == _admin;
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
    uint256 _idx = _candidateIndex[_addr];
    if (_idx == 0) {
      return;
    }

    delete _candidateInfo[_addr];
    delete _candidateIndex[_addr];
    delete _candidateCommissionChangeSchedule[_addr];

    address _lastCandidate = _candidates[_candidates.length - 1];
    if (_lastCandidate != _addr) {
      _candidateIndex[_lastCandidate] = _idx;
      _candidates[~_idx] = _lastCandidate;
    }

    _candidates.pop();
  }

  /**
   * @dev Sets timestamp to revoke a candidate.
   */
  function _setRevokingTimestamp(ValidatorCandidate storage _candidate, uint256 _timestamp) internal {
    if (!isValidatorCandidate(_candidate.consensusAddr)) revert ErrNonExistentCandidate();
    _candidate.revokingTimestamp = _timestamp;
    emit CandidateRevokingTimestampUpdated(_candidate.consensusAddr, _timestamp);
  }

  /**
   * @dev Returns a flag indicating whether the fund is unlocked.
   */
  function _emergencyExitLockedFundReleased(address _consensusAddr) internal virtual returns (bool);

  /**
   * @dev Returns whether the consensus address is a trusted org or not.
   */
  function _isTrustedOrg(address _consensusAddr) internal virtual returns (bool);
}
