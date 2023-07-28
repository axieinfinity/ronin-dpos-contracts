// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBridgeRewardEvents {
  /**
   * @dev Reward-related information for a bridge operator.
   * @param claimed The amount of rewards claimed by the bridge operator.
   * @param slashed The amount of rewards that have been slashed from the bridge operator.
   */
  struct BridgeRewardInfo {
    uint256 claimed;
    uint256 slashed;
  }

  /**
   * @dev Emitted when RON are safely received as rewards in the contract.
   * @param from The address of the sender who transferred RON tokens as rewards.
   * @param balanceBefore The balance of the contract before receiving the RON tokens.
   * @param amount The amount of RON received.
   */
  event SafeReceived(address indexed from, uint256 balanceBefore, uint256 amount);
  /// @dev Event emitted when the reward per period config is updated.
  event UpdatedRewardPerPeriod(uint256 newRewardPerPeriod);
  /// @dev Event emitted when the reward of the `operator` is scattered with `amount`.
  event BridgeRewardScattered(uint256 indexed period, address operator, uint256 amount);
  /// @dev Event emitted when the reward of the `operator` is slashed with `amount`.
  event BridgeRewardSlashed(uint256 indexed period, address operator, uint256 amount);
  /// @dev Event emitted when the reward of the `operator` is scattered with `amount` but failed to transfer.
  event BridgeRewardScatterFailed(uint256 indexed period, address operator, uint256 amount);
  /// @dev Event emitted when the requesting period to sync  is too far.
  event BridgeRewardSyncTooFarPeriod(uint256 requestingPeriod, uint256 latestPeriod);
}
