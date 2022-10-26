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

  /// @dev Mapping from vote kind => request id => flag indicating whether the receipt is recorded or not
  mapping(VoteKind => mapping(uint256 => bool)) _receiptRecorded;
  /// @dev Mapping from vote kind => request id => bridge operator address => flag indicating whether the operator voted or not
  mapping(VoteKind => mapping(uint256 => mapping(address => bool))) internal _receiptVoted;

  /// @dev The block that the contract allows incoming mutable calls.
  uint256 public startedAtBlock;

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
  function totalBallotsOf(uint256 _period, address _bridgeOperator) external view override returns (uint256) {
    return _totalBallotsOf[_period][_bridgeOperator];
  }

  /**
   * @inheritdoc IBridgeTracking
   */
  function recordVote(
    VoteKind _kind,
    uint256 _requestId,
    address _operator
  ) external override onlyBridgeContract {
    if (block.number < startedAtBlock) {
      return;
    }

    uint256 _period = _validatorContract.currentPeriod();
    if (!_receiptRecorded[_kind][_requestId]) {
      _totalVotes[_period]++;
      _receiptRecorded[_kind][_requestId] = true;
    }

    if (!_receiptVoted[_kind][_requestId][_operator]) {
      _totalBallots[_period]++;
      _totalBallotsOf[_period][_operator]++;
      _receiptVoted[_kind][_requestId][_operator] = true;
    }
  }
}
