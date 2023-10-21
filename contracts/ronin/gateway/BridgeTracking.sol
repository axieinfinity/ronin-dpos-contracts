// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../extensions/collections/HasContracts.sol";
import "../../interfaces/bridge/IBridgeTracking.sol";
import { IBridgeManager } from "../../interfaces/bridge/IBridgeManager.sol";
import { IBridgeSlash } from "../../interfaces/bridge/IBridgeSlash.sol";
import { IBridgeReward } from "../../interfaces/bridge/IBridgeReward.sol";
import { IRoninValidatorSet } from "../../interfaces/validator/IRoninValidatorSet.sol";
import { HasBridgeDeprecated, HasValidatorDeprecated } from "../../utils/DeprecatedSlots.sol";

contract BridgeTracking is HasBridgeDeprecated, HasValidatorDeprecated, HasContracts, Initializable, IBridgeTracking {
  struct PeriodVotingMetric {
    /// @dev Total requests that are tracked in the period. This value is 0 until the {_bufferMetric.requests[]} gets added into a period metric.
    uint256 totalRequest;
    uint256 totalBallot;
    mapping(address => uint256) totalBallotOf;
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
  uint256 internal _startedAtBlock;

  /// @dev The temporary info of votes and ballots
  PeriodVotingMetricTimeWrapper internal _bufferMetric;
  /// @dev Mapping from period number => vote stats based on period
  mapping(uint256 => PeriodVotingMetric) internal _periodMetric;
  /// @dev Mapping from vote kind => receipt id => receipt stats
  mapping(VoteKind => mapping(uint256 => ReceiptTrackingInfo)) internal _receiptTrackingInfo;
  /// @dev The latest period that get synced with bridge's slashing and rewarding contract
  uint256 internal _lastSyncPeriod;

  modifier skipOnNotStarted() {
    _skipOnNotStarted();
    _;
  }

  /**
   * @dev Returns the whole transaction in case the current block is less than start block.
   */
  function _skipOnNotStarted() private view {
    if (block.number < _startedAtBlock) {
      assembly {
        return(0, 0)
      }
    }
  }

  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(address bridgeContract, address validatorContract, uint256 startedAtBlock_) external initializer {
    _setContract(ContractType.BRIDGE, bridgeContract);
    _setContract(ContractType.VALIDATOR, validatorContract);
    _startedAtBlock = startedAtBlock_;
  }

  function initializeV2() external reinitializer(2) {
    _setContract(ContractType.BRIDGE, ______deprecatedBridge);
    _setContract(ContractType.VALIDATOR, ______deprecatedValidator);

    delete ______deprecatedBridge;
    delete ______deprecatedValidator;
  }

  function initializeV3(
    address bridgeManager,
    address bridgeSlash,
    address bridgeReward,
    address dposGA
  ) external reinitializer(3) {
    _setContract(ContractType.BRIDGE_MANAGER, bridgeManager);
    _setContract(ContractType.BRIDGE_SLASH, bridgeSlash);
    _setContract(ContractType.BRIDGE_REWARD, bridgeReward);
    _setContract(ContractType.GOVERNANCE_ADMIN, dposGA);
    _lastSyncPeriod = type(uint256).max;
  }

  /**
   * @dev Helper for running upgrade script, required to only revoked once by the DPoS's governance admin.
   * The following must be assured after initializing REP2:
   * `_lastSyncPeriod`
   *    == `{BridgeReward}.latestRewardedPeriod + 1`
   *    == `{BridgeSlash}._startedAtPeriod - 1`
   *    == `currentPeriod()`
   */
  function initializeREP2() external onlyContract(ContractType.GOVERNANCE_ADMIN) {
    require(_lastSyncPeriod == type(uint256).max, "already init rep 2");
    _lastSyncPeriod = IRoninValidatorSet(getContract(ContractType.VALIDATOR)).currentPeriod();
    _setContract(ContractType.GOVERNANCE_ADMIN, address(0));
  }

  /**
   * @inheritdoc IBridgeTracking
   */
  function startedAtBlock() external view override returns (uint256) {
    return _startedAtBlock;
  }

  /**
   * @inheritdoc IBridgeTracking
   */
  function totalVote(uint256 period) public view override returns (uint256 totalVote_) {
    totalVote_ = _periodMetric[period].totalRequest;
    if (_isBufferCountedForPeriod(period)) {
      totalVote_ += _bufferMetric.requests.length;
    }
  }

  /**
   * @inheritdoc IBridgeTracking
   */
  function totalBallot(uint256 period) public view override returns (uint256 totalBallot_) {
    totalBallot_ = _periodMetric[period].totalBallot;
    if (_isBufferCountedForPeriod(period)) {
      totalBallot_ += _bufferMetric.data.totalBallot;
    }
  }

  /**
   * @inheritdoc IBridgeTracking
   */
  function getManyTotalBallots(
    uint256 period,
    address[] calldata operators
  ) external view override returns (uint256[] memory _res) {
    _res = _getManyTotalBallots(period, operators);
  }

  function _getManyTotalBallots(
    uint256 period,
    address[] memory operators
  ) internal view returns (uint256[] memory res) {
    uint256 length = operators.length;
    res = new uint256[](length);
    bool isBufferCounted = _isBufferCountedForPeriod(period);
    for (uint i = 0; i < length; ) {
      res[i] = _totalBallotOf(period, operators[i], isBufferCounted);

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @inheritdoc IBridgeTracking
   */
  function totalBallotOf(uint256 period, address bridgeOperator) public view override returns (uint256) {
    return _totalBallotOf(period, bridgeOperator, _isBufferCountedForPeriod(period));
  }

  /**
   * @inheritdoc IBridgeTracking
   */
  function handleVoteApproved(
    VoteKind kind,
    uint256 requestId
  ) external override onlyContract(ContractType.BRIDGE) skipOnNotStarted {
    ReceiptTrackingInfo storage _receiptInfo = _receiptTrackingInfo[kind][requestId];

    // Only records for the receipt which not approved
    if (_receiptInfo.approvedPeriod == 0) {
      _trySyncBuffer();
      uint256 currentPeriod = IRoninValidatorSet(getContract(ContractType.VALIDATOR)).currentPeriod();
      _receiptInfo.approvedPeriod = currentPeriod;

      Request storage _bufferRequest = _bufferMetric.requests.push();
      _bufferRequest.kind = kind;
      _bufferRequest.id = requestId;

      address[] storage _voters = _receiptInfo.voters;
      for (uint i = 0; i < _voters.length; ) {
        _increaseBallot(kind, requestId, _voters[i], currentPeriod);

        unchecked {
          ++i;
        }
      }

      delete _receiptInfo.voters;
    }
  }

  /**
   * @inheritdoc IBridgeTracking
   */
  function recordVote(
    VoteKind kind,
    uint256 requestId,
    address operator
  ) external override onlyContract(ContractType.BRIDGE) skipOnNotStarted {
    uint256 period = IRoninValidatorSet(getContract(ContractType.VALIDATOR)).currentPeriod();
    _trySyncBuffer();
    ReceiptTrackingInfo storage _receiptInfo = _receiptTrackingInfo[kind][requestId];

    // When the vote is not approved yet, the voters are saved in the receipt info, and not increase ballot metric.
    // The ballot metric will be increased later in the {handleVoteApproved} method.
    if (_receiptInfo.approvedPeriod == 0) {
      _receiptInfo.voters.push(operator);
      return;
    }

    _increaseBallot(kind, requestId, operator, period);

    uint256 lastSyncPeriod = _lastSyncPeriod;
    // When switching to new period, wrap up vote info, then slash and distribute reward accordingly.
    if (lastSyncPeriod < period) {
      _lastSyncPeriod = period;

      address[] memory allOperators = IBridgeManager(getContract(ContractType.BRIDGE_MANAGER)).getBridgeOperators();
      uint256[] memory ballots = _getManyTotalBallots(lastSyncPeriod, allOperators);

      uint256 totalVote_ = totalVote(lastSyncPeriod);
      uint256 totalBallot_ = totalBallot(lastSyncPeriod);

      address bridgeSlashContract = getContract(ContractType.BRIDGE_SLASH);
      (bool success, bytes memory returnOrRevertData) = bridgeSlashContract.call(
        abi.encodeCall(
          IBridgeSlash.execSlashBridgeOperators,
          (allOperators, ballots, totalBallot_, totalVote_, lastSyncPeriod)
        )
      );
      if (!success) {
        emit ExternalCallFailed(
          bridgeSlashContract,
          IBridgeSlash.execSlashBridgeOperators.selector,
          returnOrRevertData
        );
      }

      address bridgeRewardContract = getContract(ContractType.BRIDGE_REWARD);
      (success, returnOrRevertData) = bridgeRewardContract.call(
        abi.encodeCall(IBridgeReward.execSyncReward, (allOperators, ballots, totalBallot_, totalVote_, lastSyncPeriod))
      );
      if (!success) {
        emit ExternalCallFailed(bridgeRewardContract, IBridgeReward.execSyncReward.selector, returnOrRevertData);
      }
    }
  }

  /**
   * @dev Increases the ballot for the operator at a period.
   */
  function _increaseBallot(VoteKind kind, uint256 requestId, address operator, uint256 currentPeriod) internal {
    ReceiptTrackingInfo storage _receiptInfo = _receiptTrackingInfo[kind][requestId];
    if (_receiptInfo.voted[operator]) {
      return;
    }

    _receiptInfo.voted[operator] = true;

    uint256 trackedPeriod = _receiptInfo.trackedPeriod;

    // Do not increase ballot for receipt that is neither in the buffer, nor in the most current tracked period.
    // If the receipt is not tracked in a period, increase metric in buffer.
    unchecked {
      if (trackedPeriod == 0) {
        if (_bufferMetric.data.totalBallotOf[operator] == 0) {
          _bufferMetric.data.voters.push(operator);
        }
        _bufferMetric.data.totalBallot++;
        _bufferMetric.data.totalBallotOf[operator]++;
      }
      // If the receipt is tracked in the most current tracked period, increase metric in the period.
      else if (trackedPeriod == currentPeriod) {
        PeriodVotingMetric storage _metric = _periodMetric[trackedPeriod];
        _metric.totalBallot++;
        _metric.totalBallotOf[operator]++;
      }
    }
  }

  /**
   * @dev See `totalBallotOf`.
   */
  function _totalBallotOf(
    uint256 period,
    address operator,
    bool mustCountLastStats
  ) internal view returns (uint256 _totalBallot) {
    _totalBallot = _periodMetric[period].totalBallotOf[operator];
    if (mustCountLastStats) {
      _totalBallot += _bufferMetric.data.totalBallotOf[operator];
    }
  }

  /**
   * @dev Syncs period stats. Move all data from the buffer metric to the period metric.
   *
   * Requirements:
   * - The epoch after the buffer epoch is wrapped up.
   */
  function _trySyncBuffer() internal {
    IRoninValidatorSet validatorContract = IRoninValidatorSet(getContract(ContractType.VALIDATOR));
    uint256 currentEpoch = validatorContract.epochOf(block.number);
    if (_bufferMetric.lastEpoch < currentEpoch) {
      (, uint256 trackedPeriod) = validatorContract.tryGetPeriodOfEpoch(_bufferMetric.lastEpoch + 1);
      _bufferMetric.lastEpoch = currentEpoch;

      // Copy numbers of totals
      PeriodVotingMetric storage _metric = _periodMetric[trackedPeriod];
      _metric.totalRequest += _bufferMetric.requests.length;
      _metric.totalBallot += _bufferMetric.data.totalBallot;

      // Copy voters info and voters' ballot
      for (uint i = 0; i < _bufferMetric.data.voters.length; ) {
        address voter = _bufferMetric.data.voters[i];
        _metric.totalBallotOf[voter] += _bufferMetric.data.totalBallotOf[voter];
        delete _bufferMetric.data.totalBallotOf[voter]; // need to manually delete each element, due to mapping

        unchecked {
          ++i;
        }
      }

      // Mark all receipts in the buffer as tracked. Keep total number of receipts and delete receipt details.
      for (uint i = 0; i < _bufferMetric.requests.length; ) {
        Request storage _bufferRequest = _bufferMetric.requests[i];
        ReceiptTrackingInfo storage _receiptInfo = _receiptTrackingInfo[_bufferRequest.kind][_bufferRequest.id];
        _receiptInfo.trackedPeriod = trackedPeriod;

        unchecked {
          ++i;
        }
      }

      delete _bufferMetric.requests;
      delete _bufferMetric.data;
    }
  }

  /**
   * @dev Returns whether the buffer stats must be counted or not.
   */
  function _isBufferCountedForPeriod(uint256 queriedPeriod) internal view returns (bool) {
    IRoninValidatorSet validatorContract = IRoninValidatorSet(getContract(ContractType.VALIDATOR));
    uint256 currentEpoch = validatorContract.epochOf(block.number);
    (bool filled, uint256 periodOfNextTemporaryEpoch) = validatorContract.tryGetPeriodOfEpoch(
      _bufferMetric.lastEpoch + 1
    );
    return filled && queriedPeriod == periodOfNextTemporaryEpoch && _bufferMetric.lastEpoch < currentEpoch;
  }
}
