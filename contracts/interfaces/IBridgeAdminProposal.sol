// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BridgeOperatorsBallot } from "../libraries/BridgeOperatorsBallot.sol";

interface IBridgeAdminProposal {
  /// @dev Emitted when the bridge operators are approved.
  event BridgeOperatorsApproved(uint256 period, uint256 epoch, address[] operators);

  /**
   * @dev Returns the last voted block of the bridge voter.
   */
  function lastVotedBlock(address bridgeVoter) external view returns (uint256);

  /**
   * @dev Returns the synced bridge operator set info.
   */
  function lastSyncedBridgeOperatorSetInfo()
    external
    view
    returns (BridgeOperatorsBallot.BridgeOperatorSet memory bridgeOperatorSetInfo);
}
