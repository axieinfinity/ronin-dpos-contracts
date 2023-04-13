// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../interfaces/IBridgeTracking.sol";
import "../extensions/collections/HasBridgeTrackingContract.sol";

contract MockGatewayForTracking is HasBridgeTrackingContract {
  constructor(address _bridgeTrackingContract) {
    _setBridgeTrackingContract(_bridgeTrackingContract);
  }

  function sendBallot(
    IBridgeTracking.VoteKind _kind,
    uint256 _id,
    address[] memory _voters
  ) external {
    for (uint256 _i; _i < _voters.length; _i++) {
      _bridgeTrackingContract.recordVote(_kind, _id, _voters[_i]);
    }
  }

  function sendApprovedVote(IBridgeTracking.VoteKind _kind, uint256 _id) external {
    _bridgeTrackingContract.handleVoteApproved(_kind, _id);
  }
}
