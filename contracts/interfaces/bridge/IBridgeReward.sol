// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IBridgeReward {
  struct BridgeRewardInfo {
    uint256 claimed;
    uint256 slashed;
  }

  /// @dev Event emiited when the bridge tracking contract tracks the invalid data, cause malform in sharing bridge reward.
  event BridgeTrackingIncorrectlyResponded();
  /// @dev Event emitted when the reward per period config is updated.
  event UpdatedRewardPerPeriod(uint256 newRewardPerPeriod);
  /// @dev Event emitted when the reward of the `operator` is scattered with `amount`.
  event BridgeRewardScattered(address operator, uint256 amount);
  /// @dev Event emitted when the reward of the `operator` is slashed with `amount`.
  event BridgeRewardSlashed(address operator, uint256 amount);
  /// @dev Event emitted when the reward of the `operator` is scattered with `amount` but failed to transfer.
  event BridgeRewardScatterFailed(address operator, uint256 amount);
  /// @dev Event emitted when the requesting period to sync  is too far.
  event BridgeRewardSyncTooFarPeriod(uint256 requestingPeriod, uint256 latestPeriod);

  /**
   * @dev Receives RON from any address.
   */
  function receiveRON() external payable;

  /**
   * @dev Invoke calculate and transfer reward to operators based on their performance.
   *
   * Requirements:
   * - This method is only called once each period.
   * - The caller must be the bridge tracking contract or a bridge operator.
   */
  function execSyncReward(
    address[] calldata operators,
    uint256[] calldata ballots,
    uint256 totalBallot,
    uint256 totalVote,
    uint256 period
  ) external;

  /**
   * @dev Getter for all bridge operators per period.
   */
  function getRewardPerPeriod() external view returns (uint256);

  /**
   * @dev Setter for all bridge operators per period.
   */
  function setRewardPerPeriod(uint256 rewardPerPeriod) external;
}
