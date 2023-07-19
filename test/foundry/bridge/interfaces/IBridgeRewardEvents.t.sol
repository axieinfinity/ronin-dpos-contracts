// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBridgeRewardEvents {
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
}
