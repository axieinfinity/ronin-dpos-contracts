// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/collections/HasStakingContract.sol";
import "../../extensions/consumers/PercentageConsumer.sol";
import "../../interfaces/validator/ICandidateManager.sol";
import "../../interfaces/staking/IStaking.sol";

abstract contract CandidateManager is ICandidateManager, PercentageConsumer, HasStakingContract {
  /// @dev Maximum number of validator candidate
  uint256 private _maxValidatorCandidate;

  /// @dev The validator candidate array
  address[] internal _candidates;
  /// @dev Mapping from candidate address => bitwise negation of validator index in `_candidates`
  mapping(address => uint256) internal _candidateIndex;
  /// @dev Mapping from candidate address => their info
  mapping(address => ValidatorCandidate) internal _candidateInfo;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private ______gap;

  /**
   * @inheritdoc ICandidateManager
   */
  function maxValidatorCandidate() public view override returns (uint256) {
    return _maxValidatorCandidate;
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
  function grantValidatorCandidate(
    address _admin,
    address _consensusAddr,
    address payable _treasuryAddr,
    address _bridgeOperatorAddr,
    uint256 _commissionRate
  ) external override onlyStakingContract {
    uint256 _length = _candidates.length;
    require(_length < maxValidatorCandidate(), "CandidateManager: exceeds maximum number of candidates");
    require(!isValidatorCandidate(_consensusAddr), "CandidateManager: query for already existent candidate");
    require(_commissionRate <= _MAX_PERCENTAGE, "CandidateManager: invalid comission rate");

    _candidateIndex[_consensusAddr] = ~_length;
    _candidates.push(_consensusAddr);
    _candidateInfo[_consensusAddr] = ValidatorCandidate(
      _admin,
      _consensusAddr,
      _treasuryAddr,
      _bridgeOperatorAddr,
      _commissionRate,
      type(uint256).max,
      new bytes(0)
    );
    emit CandidateGranted(_consensusAddr, _treasuryAddr, _admin, _bridgeOperatorAddr);
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function requestRevokeCandidate(address _consensusAddr, uint256 _secsLeft) external override onlyStakingContract {
    require(isValidatorCandidate(_consensusAddr), "CandidateManager: query for non-existent candidate");
    uint256 _revokedTimestamp = block.timestamp + _secsLeft;
    require(
      _revokedTimestamp < _candidateInfo[_consensusAddr].revokedTimestamp,
      "CandidateManager: invalid revoked timestamp"
    );
    _candidateInfo[_consensusAddr].revokedTimestamp = _revokedTimestamp;
    emit CandidateRevokedTimestampUpdated(_consensusAddr, _revokedTimestamp);
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
   * @dev Removes unsastisfied candidates, the ones who have insufficient minimum candidate staking amount,
   * or the ones who revoked their candidate role.
   *
   * Emits the event `CandidatesRevoked` when a candidate is revoked.
   *
   */
  function _removeUnsatisfiedCandidates() internal {
    IStaking _staking = _stakingContract;
    uint256 _minStakingAmount = _stakingContract.minValidatorStakingAmount();
    uint256[] memory _selfStakings = _staking.bulkSelfStaking(_candidates);

    uint256 _length = _candidates.length;
    uint256 _unsatisfiedCount;
    address[] memory _unsatisfiedCandidates = new address[](_length);

    {
      address _addr;
      uint256 _i;
      while (_i < _length) {
        _addr = _candidates[_i];
        if (_selfStakings[_i] < _minStakingAmount || _candidateInfo[_addr].revokedTimestamp <= block.timestamp) {
          _selfStakings[_i] = _selfStakings[--_length];
          _unsatisfiedCandidates[_unsatisfiedCount++] = _addr;
          _removeCandidate(_addr);
          continue;
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
   * @dev Removes the candidate.
   */
  function _removeCandidate(address _addr) internal {
    uint256 _idx = _candidateIndex[_addr];
    if (_idx == 0) {
      return;
    }

    delete _candidateInfo[_addr];
    delete _candidateIndex[_addr];

    address _lastCandidate = _candidates[_candidates.length - 1];

    if (_lastCandidate != _addr) {
      _candidateIndex[_lastCandidate] = _idx;
      _candidates[~_idx] = _lastCandidate;
    }

    _candidates.pop();
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
}
