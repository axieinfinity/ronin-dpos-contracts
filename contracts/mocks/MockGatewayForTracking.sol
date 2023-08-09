// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../interfaces/bridge/IBridgeTracking.sol";
import "../extensions/collections/HasContracts.sol";
import { HasBridgeTrackingDeprecated } from "../utils/DeprecatedSlots.sol";

contract MockGatewayForTracking is HasContracts, HasBridgeTrackingDeprecated {
  constructor(address bridgeTrackingContract) {
    _setContract(ContractType.BRIDGE_TRACKING, bridgeTrackingContract);
  }

  function sendBallot(IBridgeTracking.VoteKind kind, uint256 id, address[] memory voters) external {
    IBridgeTracking bridgeTrackingContract = IBridgeTracking(getContract(ContractType.BRIDGE_TRACKING));
    for (uint256 i; i < voters.length; i++) {
      bridgeTrackingContract.recordVote(kind, id, voters[i]);
    }
  }

  function sendApprovedVote(IBridgeTracking.VoteKind kind, uint256 id) external {
    IBridgeTracking(getContract(ContractType.BRIDGE_TRACKING)).handleVoteApproved(kind, id);
  }
}
