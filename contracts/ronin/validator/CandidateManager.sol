// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/collections/HasStakingContract.sol";
import "../../extensions/consumers/GlobalConfigConsumer.sol";
import "../../extensions/consumers/PercentageConsumer.sol";
import "../../interfaces/validator/ICandidateManager.sol";
import "../../interfaces/staking/IStaking.sol";

abstract contract CandidateManager is ICandidateManager, PercentageConsumer, GlobalConfigConsumer, HasStakingContract {
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
  function minEffectiveDaysOnwards() external view override returns (uint256) {
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
    address _bridgeOperatorAddr,
    uint256 _commissionRate
  ) external override onlyStakingContract {
    uint256 _length = _candidates.length;
    if (_length >= maxValidatorCandidate()) revert ErrExceedsMaxNumberOfCandidate();
    if (isValidatorCandidate(_consensusAddr)) revert ErrExistentCandidate();
    if (_commissionRate > _MAX_PERCENTAGE) revert ErrInvalidCommissionRate();

    for (uint _i; _i < _length; ) {
      ValidatorCandidate storage existentInfo = _candidateInfo[_candidates[_i]];
      if (_candidateAdmin == existentInfo.admin) revert ErrExistentCandidateAdmin(_candidateAdmin);
      if (_treasuryAddr == existentInfo.treasuryAddr) revert ErrExistentTreasury(_treasuryAddr);
      if (_bridgeOperatorAddr == existentInfo.bridgeOperatorAddr) revert ErrExistentBridgeOperator(_bridgeOperatorAddr);

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
    _info.bridgeOperatorAddr = _bridgeOperatorAddr;
    _info.commissionRate = _commissionRate;
    emit CandidateGranted(_consensusAddr, _treasuryAddr, _candidateAdmin, _bridgeOperatorAddr);
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function execRequestRenounceCandidate(address _consensusAddr, uint256 _secsLeft)
    external
    override
    onlyStakingContract
  {
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
  ) external override onlyStakingContract {
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
  function isValidatorCandidate(address _addr) public view override returns (bool yes) {
    assembly {
      mstore(0x00, _addr)
      mstore(0x20, _candidateIndex.slot)
      yes := iszero(iszero(sload(keccak256(0x00, 0x40))))
    }
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
    IStaking _staking = _stakingContract;
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
          _unsatisfiedCandidates[_unsatisfiedCount++] = _addr;
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
  function isCandidateAdmin(address _candidate, address _admin) external view override returns (bool yes) {
    assembly {
      mstore(0x00, _candidate)
      mstore(0x20, _candidateInfo.slot)

      yes := eq(sload(keccak256(0x00, 0x40)), _admin)
    }
  }

  /**
   * @dev Override `ValidatorInfoStorage-_bridgeOperatorOf`.
   */
  function _bridgeOperatorOf(address _consensusAddr) internal view virtual returns (address bridgeOperator) {
    assembly {
      mstore(0x00, _consensusAddr)
      mstore(0x20, _candidateInfo.slot)

      bridgeOperator := sload(add(3, keccak256(0x00, 0x40)))
    }
  }

  /**
   * @dev Sets the maximum number of validator candidate.
   *
   * Emits the `MaxValidatorCandidateUpdated` event.
   *
   */
  function _setMaxValidatorCandidate(uint256 _threshold) internal {
    assembly {
      sstore(_maxValidatorCandidate.slot, _threshold)
      mstore(0x00, _threshold)
      log1(
        0x00,
        0x20,
        /// @dev value is equal to keccak256("MaxValidatorCandidateUpdated(uint256)")
        0x82d5dc32d1b741512ad09c32404d7e7921e8934c6222343d95f55f7a2b9b2ab4
      )
    }
  }

  /**
   * @dev Sets the minimum number of days onwards to the effective date of commission rate change.
   *
   * Emits the `MinEffectiveDaysOnwardsUpdated` event.
   *
   */
  function _setMinEffectiveDaysOnwards(uint256 _numOfDays) internal {
    assembly {
      if lt(_numOfDays, 1) {
        mstore(0x00, 0x17b8970f)
        revert(0x1c, 0x04)
      }
      sstore(_minEffectiveDaysOnwards.slot, _numOfDays)
      mstore(0x00, _numOfDays)
      log1(
        0x00,
        0x20,
        /// @dev value is equal to keccak256("MinEffectiveDaysOnwardsUpdated(uint256)")
        0x266d432ffe659e3565750d26ec685b822a58041eee724b67a5afec3168a25267
      )
    }
  }

  /**
   * @dev Removes the candidate.
   */
  function _removeCandidate(address _addr) internal virtual {
    assembly {
      /// @dev prestore _addr for hashing
      mstore(0x00, _addr)

      mstore(0x20, _candidateIndex.slot)
      let idx := sload(keccak256(0x00, 0x40))

      /// @dev if idx != 0 continue
      if iszero(iszero(idx)) {
        /// @dev delete _candidateInfo[_addr]
        mstore(0x20, _candidateInfo.slot)

        let key := keccak256(0x00, 0x40)
        sstore(key, 0) // delete admin
        sstore(add(1, key), 0) // delete consensusAddr
        sstore(add(2, key), 0) // delete treasuryAddr
        sstore(add(3, key), 0) // delete bridgeOperatorAddr
        sstore(add(4, key), 0) // delete comissionRate
        sstore(add(5, key), 0) // delete revokingTimestamp
        sstore(add(6, key), 0) // delete topupDeadline

        /// @dev delete _candidateCommissionChangeSchedule[_addr]
        mstore(0x20, _candidateCommissionChangeSchedule.slot)
        key := keccak256(0x00, 0x40)
        sstore(key, 0) // delete effectiveTimestamp
        sstore(add(1, key), 0) // delete commissionRate

        /// @dev delete _candidateIndex[_addr]
        mstore(0x20, _candidateIndex.slot)
        key := keccak256(0x00, 0x40)
        sstore(key, 0)

        mstore(0x00, _candidates.slot)
        /// @dev get _candidates offset
        let candidateOffset := keccak256(0x00, 0x20)

        /// @dev _lastCandidate = _candidates[_candidates.length - 1]
        let lastIdx := sub(sload(_candidates.slot), 1)
        let lastIdxOffset := add(candidateOffset, lastIdx)
        let lastCandidate := sload(lastIdxOffset)

        /// @dev reduce _candidates length by 1
        sstore(_candidates.slot, lastIdx)
        /// @dev delete _candidates[_candidates.length]
        sstore(lastIdxOffset, 0)

        if iszero(eq(_addr, lastCandidate)) {
          /// @dev _candidateIndex[_lastCandidate] = _idx
          mstore(0x00, lastCandidate)
          key := keccak256(0x00, 0x40)
          sstore(key, idx)

          /// @dev _candidates[~_idx] = _lastCandidate
          sstore(add(not(idx), candidateOffset), lastCandidate)
        }
      }
    }
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
