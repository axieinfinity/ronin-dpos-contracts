// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../extensions/collections/HasBridgeContract.sol";
import "../../extensions/collections/HasValidatorContract.sol";
import "../../interfaces/IBridgeTracking.sol";

contract BridgeTracking is HasBridgeContract, HasValidatorContract, Initializable, IBridgeTracking {
  struct PeriodVotingMetric {
    /// @dev Total requests that are tracked in the period. This value is 0 until the {_bufferMetric.requests[]} gets added into a period metric.
    uint256 totalRequests;
    uint256 totalBallots;
    mapping(address => uint256) totalBallotsOf;
    address[] voters;
  }

  struct PeriodVotingMetricTimeWrapper {
    uint256 lastEpoch;
    Request[] requests;
    PeriodVotingMetric data;
  }

  struct ReceiptTrackingInfo {
    /// @dev The period that the receipt is approved. Value 0 means the receipt is not approved yet.
    uint256 approvedPeriod;
    /// @dev The address list of voters
    address[] voters;
    /// @dev Mapping from voter => flag indicating the voter casts vote for this receipt
    mapping(address => bool) voted;
    /// @dev The period that the receipt is tracked, i.e. the metric is transferred from buffer to the period. Value 0 means the receipt is currently in buffer or not tracked yet.
    uint256 trackedPeriod;
  }

  /// @dev The block that the contract allows incoming mutable calls.
  uint256 public startedAtBlock;

  /// @dev The temporary info of votes and ballots
  PeriodVotingMetricTimeWrapper internal _bufferMetric;
  /// @dev Mapping from period number => vote stats based on period
  mapping(uint256 => PeriodVotingMetric) internal _periodMetric;
  /// @dev Mapping from vote kind => receipt id => receipt stats
  mapping(VoteKind => mapping(uint256 => ReceiptTrackingInfo)) internal _receiptTrackingInfo;

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
    _totalVotes = _periodMetric[_period].totalRequests;
    if (_isBufferCountedForPeriod(_period)) {
      _totalVotes += _bufferMetric.requests.length;
    }
  }

  /**
   * @inheritdoc IBridgeTracking
   */
  function totalBallots(uint256 _period) external view override returns (uint256 _totalBallots) {
    _totalBallots = _periodMetric[_period].totalBallots;
    if (_isBufferCountedForPeriod(_period)) {
      _totalBallots += _bufferMetric.data.totalBallots;
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
    bool _isBufferCounted = _isBufferCountedForPeriod(_period);
    for (uint _i = 0; _i < _bridgeOperators.length; ) {
      _res[_i] = _totalBallotsOf(_period, _bridgeOperators[_i], _isBufferCounted);

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @inheritdoc IBridgeTracking
   */
  function totalBallotsOf(uint256 _period, address _bridgeOperator) public view override returns (uint256) {
    return _totalBallotsOf(_period, _bridgeOperator, _isBufferCountedForPeriod(_period));
  }

  /**
   * @inheritdoc IBridgeTracking
   */
  function handleVoteApproved(VoteKind _kind, uint256 _requestId) external override onlyBridgeContract skipOnUnstarted {
    ReceiptTrackingInfo storage _receiptInfo = _receiptTrackingInfo[_kind][_requestId];

    // Only records for the receipt which not approved
    if (_receiptInfo.approvedPeriod == 0) {
      _trySyncBuffer();
      uint256 _currentPeriod = _validatorContract.currentPeriod();
      _receiptInfo.approvedPeriod = _currentPeriod;

      Request storage _bufferRequest = _bufferMetric.requests.push();
      _bufferRequest.kind = _kind;
      _bufferRequest.id = _requestId;

      address[] storage _voters = _receiptInfo.voters;
      for (uint _i = 0; _i < _voters.length; ) {
        _increaseBallot(_kind, _requestId, _voters[_i], _currentPeriod);

        unchecked {
          ++_i;
        }
      }

      delete _receiptInfo.voters;
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
    _trySyncBuffer();
    ReceiptTrackingInfo storage _receiptInfo = _receiptTrackingInfo[_kind][_requestId];

    // When the vote is not approved yet, the voters are saved in the receipt info, and not increase ballot metric.
    // The ballot metric will be increased later in the {handleVoteApproved} method.
    if (_receiptInfo.approvedPeriod == 0) {
      _receiptInfo.voters.push(_operator);
      return;
    }

    _increaseBallot(_kind, _requestId, _operator, _period);
  }

  /**
   * @dev Increases the ballot for the operator at a period.
   */
  function _increaseBallot(
    VoteKind _kind,
    uint256 _requestId,
    address _operator,
    uint256 _currentPeriod
  ) internal {
    ReceiptTrackingInfo storage _receiptInfo = _receiptTrackingInfo[_kind][_requestId];
    if (_receiptInfo.voted[_operator]) {
      return;
    }

    _receiptInfo.voted[_operator] = true;

    uint256 _trackedPeriod = _receiptInfo.trackedPeriod;

    // Do not increase ballot for receipt that is neither in the buffer, nor in the most current tracked period.
    // If the receipt is not tracked in a period, increase metric in buffer.
    if (_trackedPeriod == 0) {
      if (_bufferMetric.data.totalBallotsOf[_operator] == 0) {
        _bufferMetric.data.voters.push(_operator);
      }
      _bufferMetric.data.totalBallots++;
      _bufferMetric.data.totalBallotsOf[_operator]++;
    }
    // If the receipt is tracked in the most current tracked period, increase metric in the period.
    else if (_trackedPeriod == _currentPeriod) {
      PeriodVotingMetric storage _metric = _periodMetric[_trackedPeriod];
      _metric.totalBallots++;
      _metric.totalBallotsOf[_operator]++;
    }
  }

  /**
   * @dev See `totalBallotsOf`.
   */
  function _totalBallotsOf(
    uint256 _period,
    address _bridgeOperator,
    bool _mustCountLastStats
  ) internal view returns (uint256 _totalBallots) {
    _totalBallots = _periodMetric[_period].totalBallotsOf[_bridgeOperator];
    if (_mustCountLastStats) {
      _totalBallots += _bufferMetric.data.totalBallotsOf[_bridgeOperator];
    }
  }

  /**
   * @dev Syncs period stats. Move all data from the buffer metric to the period metric.
   *
   * Requirements:
   * - The epoch after the buffer epoch is wrapped up.
   */
  function _trySyncBuffer() internal {
    uint256 _currentEpoch = _validatorContract.epochOf(block.number);
    if (_bufferMetric.lastEpoch < _currentEpoch) {
      (, uint256 _trackedPeriod) = _validatorContract.tryGetPeriodOfEpoch(_bufferMetric.lastEpoch + 1);
      _bufferMetric.lastEpoch = _currentEpoch;

      // Copy numbers of totals
      PeriodVotingMetric storage _metric = _periodMetric[_trackedPeriod];
      _metric.totalRequests += _bufferMetric.requests.length;
      _metric.totalBallots += _bufferMetric.data.totalBallots;

      // Copy voters info and voters' ballot
      for (uint _i = 0; _i < _bufferMetric.data.voters.length; ) {
        address _voter = _bufferMetric.data.voters[_i];
        _metric.totalBallotsOf[_voter] += _bufferMetric.data.totalBallotsOf[_voter];
        delete _bufferMetric.data.totalBallotsOf[_voter]; // need to manually delete each element, due to mapping

        unchecked {
          ++_i;
        }
      }

      // Mark all receipts in the buffer as tracked. Keep total number of receipts and delete receipt details.
      for (uint _i = 0; _i < _bufferMetric.requests.length; ) {
        Request storage _bufferRequest = _bufferMetric.requests[_i];
        ReceiptTrackingInfo storage _receiptInfo = _receiptTrackingInfo[_bufferRequest.kind][_bufferRequest.id];
        _receiptInfo.trackedPeriod = _trackedPeriod;

        unchecked {
          ++_i;
        }
      }

      delete _bufferMetric.requests;
      delete _bufferMetric.data;
    }
  }

  /**
   * @dev Returns whether the buffer stats must be counted or not.
   */
  function _isBufferCountedForPeriod(uint256 _queriedPeriod) internal view returns (bool) {
    uint256 _currentEpoch = _validatorContract.epochOf(block.number);
    (bool _filled, uint256 _periodOfNextTemporaryEpoch) = _validatorContract.tryGetPeriodOfEpoch(
      _bufferMetric.lastEpoch + 1
    );
    return _filled && _queriedPeriod == _periodOfNextTemporaryEpoch && _bufferMetric.lastEpoch < _currentEpoch;
  }
}
