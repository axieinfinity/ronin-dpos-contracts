// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../extensions/collections/HasBridgeContract.sol";
import "../extensions/collections/HasValidatorContract.sol";
import "../interfaces/IBridgeTracking.sol";

contract BridgeTracking is HasBridgeContract, HasValidatorContract, Initializable, IBridgeTracking {
  /// @dev Mapping from period number => total number of votes
  mapping(uint256 => uint256) internal _totalVotes;
  /// @dev Mapping from period number => bridge operator address => total number of votes
  mapping(uint256 => mapping(address => uint256)) internal _totalVotesOf;

  /// @dev Mapping from vote kind => request id => flag indicating whether the receipt is recorded or not
  mapping(VoteKind => mapping(uint256 => bool)) _receiptRecorded;
  /// @dev Mapping from vote kind => request id => bridge operator address => flag indicating whether the operator voted or not
  mapping(VoteKind => mapping(uint256 => mapping(address => bool))) internal _receiptVoted;

  /// @dev The block that the contract allows incoming mutable calls.
  uint256 public startedAtBlock;

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(uint256 _startedAtBlock) external initializer {
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
  function totalVotesOf(uint256 _period, address _bridgeOperator) external view override returns (uint256) {
    return _totalVotesOf[_period][_bridgeOperator];
  }

  /**
   * @inheritdoc IBridgeTracking
   */
  function recordVote(
    VoteKind _kind,
    uint256 _requestId,
    address _operator
  ) external override {
    if (block.number < startedAtBlock) {
      return;
    }

    uint256 _period = _validatorContract.currentPeriod();
    if (!_receiptRecorded[_kind][_requestId]) {
      _totalVotes[_period]++;
      _receiptRecorded[_kind][_requestId] = true;
    }

    if (!_receiptVoted[_kind][_requestId][_operator]) {
      _totalVotesOf[_period][_operator]++;
      _receiptVoted[_kind][_requestId][_operator] = true;
    }
  }
}
