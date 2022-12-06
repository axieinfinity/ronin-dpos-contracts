// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../extensions/collections/HasBridgeContract.sol";
import "../extensions/collections/HasValidatorContract.sol";
import "../interfaces/IBridgeTracking.sol";

contract BridgeTracking is HasBridgeContract, HasValidatorContract, Initializable, IBridgeTracking {
  struct VoteStats {
    uint256 totalVotes;
    uint256 totalBallots;
    mapping(address => uint256) totalBallotsOf;
    address[] voters;
  }

  struct VoteStatsTimeWrapper {
    uint256 lastEpoch;
    VoteStats info;
  }

  struct ReceiptStats {
    // The period that the receipt is approved
    uint256 approvedPeriod;
    // The address list of voters
    address[] voters;
    // Mapping from voter => flag indicating the voter casts vote for this receipt
    mapping(address => bool) voted;
  }

  /// @dev Deprecated slots.
  uint256[6] private __deprecated;

  /// @dev The block that the contract allows incoming mutable calls.
  uint256 public startedAtBlock;

  /// @dev The temporary info of votes and ballots
  VoteStatsTimeWrapper internal _temporaryStats;
  /// @dev Mapping from period number => vote stats based on period
  mapping(uint256 => VoteStats) internal _periodStats;
  /// @dev Mapping from vote kind => receipt id => receipt stats
  mapping(VoteKind => mapping(uint256 => ReceiptStats)) internal _receiptStats;

  modifier skipOnUnstarted() {
    if (block.number < startedAtBlock) {
      return;
    }
    _;
  }

  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(
    address _bridgeContract,
    address _validatorContract,
    uint256 _startedAtBlock
  ) external initializer {
    _setBridgeContract(_bridgeContract);
    _setValidatorContract(_validatorContract);
    startedAtBlock = _startedAtBlock;
  }

  /**
   * @inheritdoc IBridgeTracking
   */
  function totalVotes(uint256 _period) external view override returns (uint256 _totalVotes) {
    _totalVotes = _periodStats[_period].totalVotes;

    uint256 _currentEpoch = _validatorContract.epochOf(block.number);
    uint256 _periodOfNextTemporaryEpoch = _validatorContract.periodOf(_temporaryStats.lastEpoch + 1);
    // Counts the last stats for the period if the last epoch is passed.
    if (_period == _periodOfNextTemporaryEpoch && _temporaryStats.lastEpoch < _currentEpoch) {
      _totalVotes += _temporaryStats.info.totalVotes;
    }
  }

  /**
   * @inheritdoc IBridgeTracking
   */
  function totalBallots(uint256 _period) external view override returns (uint256 _totalBallots) {
    _totalBallots = _periodStats[_period].totalBallots;

    uint256 _currentEpoch = _validatorContract.epochOf(block.number);
    uint256 _periodOfNextTemporaryEpoch = _validatorContract.periodOf(_temporaryStats.lastEpoch + 1);
    // Counts the last stats for the period if the last epoch is passed.
    if (_period == _periodOfNextTemporaryEpoch && _temporaryStats.lastEpoch < _currentEpoch) {
      _totalBallots += _temporaryStats.info.totalBallots;
    }
  }

  /**
   * @inheritdoc IBridgeTracking
   */
  function getManyTotalBallots(uint256 _period, address[] calldata _bridgeOperators)
    external
    view
    override
    returns (uint256[] memory _res)
  {
    _res = new uint256[](_bridgeOperators.length);
    uint256 _currentEpoch = _validatorContract.epochOf(block.number);
    uint256 _periodOfNextTemporaryEpoch = _validatorContract.periodOf(_temporaryStats.lastEpoch + 1);
    for (uint _i = 0; _i < _bridgeOperators.length; _i++) {
      _res[_i] = _totalBallotsOf(_period, _currentEpoch, _bridgeOperators[_i], _periodOfNextTemporaryEpoch);
    }
  }

  /**
   * @inheritdoc IBridgeTracking
   */
  function totalBallotsOf(uint256 _period, address _bridgeOperator) public view override returns (uint256) {
    return
      _totalBallotsOf(
        _period,
        _validatorContract.epochOf(block.number),
        _bridgeOperator,
        _validatorContract.periodOf(_temporaryStats.lastEpoch + 1)
      );
  }

  /**
   * @inheritdoc IBridgeTracking
   */
  function handleVoteApproved(VoteKind _kind, uint256 _requestId) external override onlyBridgeContract skipOnUnstarted {
    ReceiptStats storage _stats = _receiptStats[_kind][_requestId];

    // Only records for the receipt which not approved
    if (_stats.approvedPeriod == 0) {
      uint256 _currentPeriod = _validatorContract.currentPeriod();
      _syncPeriodStats(_validatorContract.epochOf(block.number));
      _temporaryStats.info.totalVotes++;
      _stats.approvedPeriod = _currentPeriod;

      address[] storage _voters = _stats.voters;
      for (uint _i = 0; _i < _voters.length; _i++) {
        _increaseBallot(_kind, _requestId, _voters[_i], _currentPeriod);
      }

      delete _stats.voters;
    }
  }

  /**
   * @inheritdoc IBridgeTracking
   */
  function recordVote(
    VoteKind _kind,
    uint256 _requestId,
    address _operator
  ) external override onlyBridgeContract skipOnUnstarted {
    uint256 _period = _validatorContract.currentPeriod();
    _syncPeriodStats(_validatorContract.epochOf(block.number));
    ReceiptStats storage _stats = _receiptStats[_kind][_requestId];

    // Stores the ones vote for the (deposit/mainchain withdrawal) request which is not approved yet
    if (_stats.approvedPeriod == 0) {
      _stats.voters.push(_operator);
      return;
    }

    _increaseBallot(_kind, _requestId, _operator, _period);
  }

  /**
   * Increases the ballot for the operator at a period.
   */
  function _increaseBallot(
    VoteKind _kind,
    uint256 _requestId,
    address _operator,
    uint256 _period
  ) internal {
    ReceiptStats storage _receiptInfo = _receiptStats[_kind][_requestId];
    if (_receiptInfo.voted[_operator]) {
      return;
    }

    _receiptInfo.voted[_operator] = true;

    // Only records within a period
    if (_receiptInfo.approvedPeriod == _period) {
      if (_temporaryStats.info.totalBallotsOf[_operator] == 0) {
        _temporaryStats.info.voters.push(_operator);
      }
      _temporaryStats.info.totalBallots++;
      _temporaryStats.info.totalBallotsOf[_operator]++;
    }
  }

  /**
   * @dev See `totalBallotsOf`.
   */
  function _totalBallotsOf(
    uint256 _period,
    uint256 _currentEpoch,
    address _bridgeOperator,
    uint256 _periodOfNextTemporaryEpoch
  ) internal view returns (uint256 _totalBallots) {
    _totalBallots = _periodStats[_period].totalBallotsOf[_bridgeOperator];
    // Counts the last stats for the period if the last epoch is passed.
    if (_period == _periodOfNextTemporaryEpoch && _temporaryStats.lastEpoch < _currentEpoch) {
      _totalBallots += _temporaryStats.info.totalBallotsOf[_bridgeOperator];
    }
  }

  /**
   * @dev Syncs period stats if the last epoch + 1 is already wrapped up.
   */
  function _syncPeriodStats(uint256 _currentEpoch) internal {
    if (_temporaryStats.lastEpoch < _currentEpoch) {
      uint256 _period = _validatorContract.periodOf(_temporaryStats.lastEpoch + 1);
      VoteStats storage _stats = _periodStats[_period];
      _stats.totalVotes += _temporaryStats.info.totalVotes;
      _stats.totalBallots += _temporaryStats.info.totalBallots;

      address _voter;
      for (uint _i = 0; _i < _temporaryStats.info.voters.length; _i++) {
        _voter = _temporaryStats.info.voters[_i];
        _stats.totalBallotsOf[_voter] += _temporaryStats.info.totalBallotsOf[_voter];
        delete _temporaryStats.info.totalBallotsOf[_voter];
      }
      delete _temporaryStats.info;
      _temporaryStats.lastEpoch = _currentEpoch;
    }
  }
}
