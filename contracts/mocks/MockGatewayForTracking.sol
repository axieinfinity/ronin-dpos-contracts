// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../interfaces/IBridgeTracking.sol";
import "../extensions/collections/HasContracts.sol";
import { HasBridgeTrackingDeprecated } from "../utils/DeprecatedSlots.sol";

contract MockGatewayForTracking is HasContracts, HasBridgeTrackingDeprecated {
  constructor(address _bridgeTrackingContract) {
    _setContract(ContractType.BRIDGE_TRACKING, _bridgeTrackingContract);
  }

  function sendBallot(IBridgeTracking.VoteKind _kind, uint256 _id, address[] memory _voters) external {
    IBridgeTracking bridgeTrackingContract = IBridgeTracking(getContract(ContractType.BRIDGE_TRACKING));
    for (uint256 _i; _i < _voters.length; _i++) {
      bridgeTrackingContract.recordVote(_kind, _id, _voters[_i]);
    }
  }

  function sendApprovedVote(IBridgeTracking.VoteKind _kind, uint256 _id) external {
    IBridgeTracking(getContract(ContractType.BRIDGE_TRACKING)).handleVoteApproved(_kind, _id);
  }
}
