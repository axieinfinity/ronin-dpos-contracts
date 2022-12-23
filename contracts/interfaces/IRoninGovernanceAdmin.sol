// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRoninGovernanceAdmin {
  /// @dev Emitted when the bridge operators are approved.
  event BridgeOperatorsApproved(uint256 _period, uint256 _epoch, address[] _operators);
  /// @dev Emitted when an emergency exit poll is created.
  event EmergencyExitPollCreated(
    bytes32 _voteHash,
    address _consensusAddr,
    address _recipientAfterUnlockedFund,
    uint256 _requestedAt,
    uint256 _expiredAt
  );
  /// @dev Emitted when an emergency exit poll is approved.
  event EmergencyExitPollApproved(bytes32 _voteHash);
  /// @dev Emitted when an emergency exit poll is expired.
  event EmergencyExitPollExpired(bytes32 _voteHash);

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
  function createEmergencyExitPoll(
    address _consensusAddr,
    address _recipientAfterUnlockedFund,
    uint256 _requestedAt,
    uint256 _expiredAt
  ) external;
}
