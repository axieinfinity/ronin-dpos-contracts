// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../extensions/HasStakingContract.sol";
import "../interfaces/ICandidateManager.sol";
import "../interfaces/IStaking.sol";
import "../libraries/Sorting.sol";

abstract contract CandidateManager is ICandidateManager, HasStakingContract {
  /// @dev Maximum number of validator candidate
  uint256 private _maxValidatorCandidate;

  /// @dev The validator candidate array
  address[] internal _candidates;
  /// @dev Mapping from candidate address => bitwise negation of validator index in `_candidates`
  mapping(address => uint256) internal _candidateIndex;
  /// @dev Mapping from candidate address => their info
  mapping(address => ValidatorCandidate) internal _candidateInfo;

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
  function addValidatorCandidate(
    address _admin,
    address _consensusAddr,
    address payable _treasuryAddr,
    uint256 _commissionRate
  ) external override onlyStakingContract {
    uint256 _length = _candidates.length;
    require(_length < maxValidatorCandidate(), "CandidateManager: exceeds maximum number of candidates");
    require(!isValidatorCandidate(_consensusAddr), "CandidateManager: query for already existent candidate");

    _candidateIndex[_consensusAddr] = ~_length;
    _candidates.push(_consensusAddr);
    _candidateInfo[_consensusAddr] = ValidatorCandidate(
      _admin,
      _consensusAddr,
      _treasuryAddr,
      _commissionRate,
      type(uint256).max,
      new bytes(0)
    );
    emit CandidateAdded(_consensusAddr, _treasuryAddr, _admin);
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function requestRemoveCandidate(address _consensusAddr) external override onlyStakingContract {
    require(isValidatorCandidate(_consensusAddr), "CandidateManager: query for non-existent candidate");
    uint256 _blockLength = numberOfBlocksInEpoch() * numberOfEpochsInPeriod();
    uint256 _removedAtBlock = (block.number / _blockLength) * _blockLength + _blockLength * 2 - 1;
    require(_removedAtBlock < _candidateInfo[_consensusAddr].removedAtBlock, "CandidateManager: invalid block number");
    _candidateInfo[_consensusAddr].removedAtBlock = _removedAtBlock;
    emit CandidateRemovedAtBlock(_consensusAddr, _removedAtBlock);
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
  function getValidatorCandidates() public view override returns (address[] memory) {
    return _candidates;
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function numberOfEpochsInPeriod() public view virtual returns (uint256);

  /**
   * @inheritdoc ICandidateManager
   */
  function numberOfBlocksInEpoch() public view virtual returns (uint256);

  /**
   * @dev Removes unsastisfied candidates (the ones who have insufficient minimum candidate balance).
   * Returns the total balance list of the new candidate list.
   *
   * Emits the event `CandidatesRemoved` when a candidate is removed.
   *
   */
  function _filterUnsatisfiedCandidates(uint256 _minBalance) internal returns (uint256[] memory _balances) {
    IStaking _staking = _stakingContract;
    _balances = _staking.totalBalances(_candidates);

    uint256 _length = _candidates.length;
    address[] memory _unsatisfiedCandidates = new address[](_length);
    uint256 _unsatisfiedCount;
    address _addr;
    for (uint _i = 0; _i < _length; _i++) {
      _addr = _candidates[_i];
      if (_balances[_i] < _minBalance || _candidateInfo[_addr].removedAtBlock <= block.number) {
        _balances[_i] = _balances[--_length];
        _unsatisfiedCandidates[_unsatisfiedCount++] = _addr;
        _removeCandidate(_addr);
      }
    }

    if (_unsatisfiedCount > 0) {
      assembly {
        mstore(_unsatisfiedCandidates, _unsatisfiedCount)
      }
      emit CandidatesRemoved(_unsatisfiedCandidates);
      _staking.deprecatePools(_unsatisfiedCandidates);
    }

    assembly {
      mstore(_balances, _length)
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
    _candidateIndex[_lastCandidate] = _idx;

    _candidates[~_idx] = _lastCandidate;
    _candidates.pop();
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
