// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBridgeRewardEvents {
  struct BridgeRewardInfo {
    uint256 claimed;
    uint256 slashed;
  }

  /// @dev Event emiited when the bridge tracking contract tracks the invalid data, cause malform in sharing bridge reward.
  event BridgeTrackingIncorrectlyResponded();
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
