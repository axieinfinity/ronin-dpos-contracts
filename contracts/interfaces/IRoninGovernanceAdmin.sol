// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRoninGovernanceAdmin {
  /**
   * @dev Returns the last voted block of the bridge voter.
   */
  function lastVotedBlock(address _bridgeVoter) external view returns (uint256);

  /**
   * @dev Create a vote to agree that an emergency exit is valid and should return the locked funds back.a
   *
   * Requirements:
   * - The method caller is validator contract.
   *
   */
  function createEmergencyExitVote(
    address _consensusAddr,
    address _recipientAfterUnlockedFund,
    uint256 _requestedAt,
    uint256 _expiredAt
  ) external;
}
