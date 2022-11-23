// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../extensions/collections/HasBridgeContract.sol";
import "../extensions/collections/HasValidatorContract.sol";
import "../interfaces/IBridgeTracking.sol";

contract BridgeTracking is HasBridgeContract, HasValidatorContract, Initializable, IBridgeTracking {
  /// @dev Mapping from period number => total number of all votes
  mapping(uint256 => uint256) internal _totalVotes;
  /// @dev Mapping from period number => total number of all ballots
  mapping(uint256 => uint256) internal _totalBallots;
  /// @dev Mapping from period number => bridge operator address => total number of ballots
  mapping(uint256 => mapping(address => uint256)) internal _totalBallotsOf;

  /// @dev Mapping from vote kind => request id => the period that the receipt is approved
  mapping(VoteKind => mapping(uint256 => uint256)) internal _receiptApprovedAt;
  /// @dev Mapping from vote kind => request id => the voters
  mapping(VoteKind => mapping(uint256 => address[])) internal _receiptVoters;
  /// @dev Mapping from vote kind => request id => bridge operator address => flag indicating whether the operator voted or not
  mapping(VoteKind => mapping(uint256 => mapping(address => bool))) internal _receiptVoted;

  /// @dev The block that the contract allows incoming mutable calls.
  uint256 public startedAtBlock;

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
  function totalVotes(uint256 _period) external view override returns (uint256) {
    return _totalVotes[_period];
  }

  /**
   * @inheritdoc IBridgeTracking
   */
  function totalBallots(uint256 _period) external view override returns (uint256) {
    return _totalBallots[_period];
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
    for (uint _i = 0; _i < _bridgeOperators.length; _i++) {
      _res[_i] = totalBallotsOf(_period, _bridgeOperators[_i]);
    }
  }

  /**
   * @inheritdoc IBridgeTracking
   */
  function totalBallotsOf(uint256 _period, address _bridgeOperator) public view override returns (uint256) {
    return _totalBallotsOf[_period][_bridgeOperator];
  }

  /**
   * @inheritdoc IBridgeTracking
   */
  function handleVoteApproved(VoteKind _kind, uint256 _requestId) external override onlyBridgeContract skipOnUnstarted {
    // Only records for the receipt which not approved
    if (_receiptApprovedAt[_kind][_requestId] == 0) {
      uint256 _period = _validatorContract.currentPeriod();
      _totalVotes[_period]++;
      _receiptApprovedAt[_kind][_requestId] = _period;

      address[] storage _voters = _receiptVoters[_kind][_requestId];
      for (uint _i = 0; _i < _voters.length; _i++) {
        increaseBallot(_kind, _requestId, _voters[_i], _period);
      }

      delete _receiptVoters[_kind][_requestId];
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
    uint256 _approvedPeriod = _receiptApprovedAt[_kind][_requestId];

    // Stores the ones vote for the (deposit/mainchain withdrawal) request which not approved yet
    if (_approvedPeriod == 0) {
      if (_kind != VoteKind.Withdrawal) {
        _receiptVoters[_kind][_requestId].push(_operator);
      }
      return;
    }

    uint256 _period = _validatorContract.currentPeriod();
    // Only records within a period
    if (_approvedPeriod == _period) {
      increaseBallot(_kind, _requestId, _operator, _period);
    }
  }

  /**
   * Increases the ballot for the operator at a period.
   */
  function increaseBallot(
    VoteKind _kind,
    uint256 _requestId,
    address _operator,
    uint256 _period
  ) internal {
    if (_receiptVoted[_kind][_requestId][_operator]) {
      return;
    }

    _totalBallots[_period]++;
    _totalBallotsOf[_period][_operator]++;
    _receiptVoted[_kind][_requestId][_operator] = true;
  }
}
