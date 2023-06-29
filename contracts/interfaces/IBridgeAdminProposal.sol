// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BridgeOperatorsBallot } from "../libraries/BridgeOperatorsBallot.sol";

interface IBridgeAdminProposal {
  /// @dev Emitted when the bridge operators are approved.
  event BridgeOperatorsApproved(uint256 _period, uint256 _epoch, address[] _operators);

  /**
   * @dev Returns the last voted block of the bridge voter.
   */
  function lastVotedBlock(address _bridgeVoter) external view returns (uint256);

  /**
   * @dev Returns the synced bridge operator set info.
   */
  function lastSyncedBridgeOperatorSetInfo()
    external
    view
    returns (BridgeOperatorsBallot.BridgeOperatorSet memory _bridgeOperatorSetInfo);
}
