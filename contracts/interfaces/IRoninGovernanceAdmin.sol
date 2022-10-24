// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRoninGovernanceAdmin {
  /**
   * @dev Returns the last voted block of the bridge voter.
   */
  function lastVotedBlock(address _bridgeVoter) external view returns (uint256);
}
