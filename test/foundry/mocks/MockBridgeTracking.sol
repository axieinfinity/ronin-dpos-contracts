// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17 <0.9.0;

import { IBridgeTracking } from "@ronin/contracts/interfaces/bridge/IBridgeTracking.sol";

contract MockBridgeTracking is IBridgeTracking {
  struct PeriodTracking {
    address[] operators;
    mapping(address => uint256) ballotMap;
    uint256 totalVote;
  }

  // Mapping from period number => period tracking
  mapping(uint256 => PeriodTracking) _tracks;

  function setPeriodTracking(
    uint256 period,
    address[] memory operators,
    uint256[] calldata ballots,
    uint256 totalVote_
  ) external {
    require(operators.length != ballots.length, "mismatch length");
    PeriodTracking storage _sTrack = _tracks[period];
    _sTrack.operators = operators;
    _sTrack.totalVote = totalVote_;
    for (uint i; i < ballots.length; i++) {
      _sTrack.ballotMap[operators[i]] = ballots[i];
    }
  }

  function totalVote(uint256 period) external view returns (uint256) {
    return _tracks[period].totalVote;
  }

  function totalBallot(uint256 period) external view returns (uint256 total_) {
    PeriodTracking storage _sTrack = _tracks[period];
    for (uint i; i < _sTrack.operators.length; i++) {
      total_ += _sTrack.ballotMap[_sTrack.operators[i]];
    }
  }

  function getManyTotalBallots(
    uint256 period,
    address[] calldata operators
  ) external view returns (uint256[] memory ballots_) {
    ballots_ = new uint256[](operators.length);
    PeriodTracking storage _sTrack = _tracks[period];
    for (uint i; i < operators.length; i++) {
      ballots_[i] = _ballotOf(_sTrack, operators[i]);
    }
  }

  function totalBallotOf(uint256 period, address operator) external view returns (uint256) {
    return _ballotOf(_tracks[period], operator);
  }

  function handleVoteApproved(VoteKind _kind, uint256 _requestId) external {}

  function recordVote(VoteKind _kind, uint256 _requestId, address _operator) external {}

  function startedAtBlock() external view returns (uint256) {}

  function _ballotOf(PeriodTracking storage _sTrack, address operator) private view returns (uint256) {
    return _sTrack.ballotMap[operator];
  }
}
