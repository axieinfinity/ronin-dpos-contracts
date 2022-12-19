// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";
import "../../extensions/collections/HasStakingContract.sol";
import "../../extensions/consumers/PercentageConsumer.sol";
import "../../interfaces/validator/ICandidateManager.sol";
import "../../interfaces/staking/IStaking.sol";

abstract contract CandidateManager is ICandidateManager, PercentageConsumer, HasStakingContract {
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
  function grantValidatorCandidate(
    address _candidateAdmin,
    address _consensusAddr,
    address payable _treasuryAddr,
    address _bridgeOperatorAddr,
    uint256 _commissionRate
  ) external override onlyStakingContract {
    uint256 _length = _candidates.length;
    require(_length < maxValidatorCandidate(), "CandidateManager: exceeds maximum number of candidates");
    require(!isValidatorCandidate(_consensusAddr), "CandidateManager: query for already existent candidate");
    require(_commissionRate <= _MAX_PERCENTAGE, "CandidateManager: invalid comission rate");

    for (uint _i = 0; _i < _candidates.length; _i++) {
      ValidatorCandidate storage existentInfo = _candidateInfo[_candidates[_i]];

      if (_candidateAdmin == existentInfo.admin) {
        revert(
          string(
            abi.encodePacked(
              "CandidateManager: candidate admin address ",
              Strings.toHexString(uint160(_candidateAdmin), 20),
              " is already exist"
            )
          )
        );
      }

      if (_treasuryAddr == existentInfo.treasuryAddr) {
        revert(
          string(
            abi.encodePacked(
              "CandidateManager: treasury address ",
              Strings.toHexString(uint160(address(_treasuryAddr)), 20),
              " is already exist"
            )
          )
        );
      }

      if (_bridgeOperatorAddr == existentInfo.bridgeOperatorAddr) {
        revert(
          string(
            abi.encodePacked(
              "CandidateManager: bridge operator address ",
              Strings.toHexString(uint160(_bridgeOperatorAddr), 20),
              " is already exist"
            )
          )
        );
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
  function requestRevokeCandidate(address _consensusAddr, uint256 _secsLeft) external override onlyStakingContract {
    ValidatorCandidate storage _info = _candidateInfo[_consensusAddr];
    require(_info.revokingTimestamp == 0, "CandidateManager: already requested before");
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
    require(
      _candidateCommissionChangeSchedule[_consensusAddr].effectiveTimestamp == 0,
      "CandidateManager: commission change schedule exists"
    );
    require(_commissionRate <= _MAX_PERCENTAGE, "CandidateManager: invalid commission rate");
    require(_effectiveDaysOnwards >= _minEffectiveDaysOnwards, "CandidateManager: invalid effective date");

    CommissionSchedule storage _schedule = _candidateCommissionChangeSchedule[_consensusAddr];
    uint256 _effectiveTimestamp = ((block.timestamp / 1 days) + _effectiveDaysOnwards) * 1 days;
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
    for (uint _i = 0; _i < _list.length; _i++) {
      _list[_i] = _candidateInfo[_candidates[_i]];
    }
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function getCandidateInfo(address _candidate) external view override returns (ValidatorCandidate memory) {
    require(isValidatorCandidate(_candidate), "CandidateManager: query for non-existent candidate");
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
  function _syncCandidateSet() internal {
    IStaking _staking = _stakingContract;
    uint256 _waitingSecsToRevoke = _staking.waitingSecsToRevoke();
    uint256 _minStakingAmount = _staking.minValidatorStakingAmount();
    uint256[] memory _selfStakings = _staking.getManySelfStakings(_candidates);

    uint256 _length = _candidates.length;
    uint256 _unsatisfiedCount;
    address[] memory _unsatisfiedCandidates = new address[](_length);

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
        bool _revokingActivated = _info.revokingTimestamp != 0 && _info.revokingTimestamp <= block.timestamp;
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

        _i++;
      }
    }

    if (_unsatisfiedCount > 0) {
      assembly {
        mstore(_unsatisfiedCandidates, _unsatisfiedCount)
      }
      emit CandidatesRevoked(_unsatisfiedCandidates);
      _staking.deprecatePools(_unsatisfiedCandidates);
    }
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function isCandidateAdmin(address _candidate, address _admin) external view override returns (bool) {
    return _candidateInfo[_candidate].admin == _admin;
  }

  /**
   * @dev Override `ValidatorInfoStorage-_bridgeOperatorOf`.
   */
  function _bridgeOperatorOf(address _consensusAddr) internal view virtual returns (address) {
    return _candidateInfo[_consensusAddr].bridgeOperatorAddr;
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
    require(_numOfDays >= 1, "CandidateManager: invalid min effective days onwards");
    _minEffectiveDaysOnwards = _numOfDays;
    emit MinEffectiveDaysOnwardsUpdated(_numOfDays);
  }

  /**
   * @dev Removes the candidate.
   */
  function _removeCandidate(address _addr) private {
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
    require(isValidatorCandidate(_candidate.consensusAddr), "CandidateManager: query for non-existent candidate");
    _candidate.revokingTimestamp = _timestamp;
    emit CandidateRevokingTimestampUpdated(_candidate.consensusAddr, _timestamp);
  }
}
