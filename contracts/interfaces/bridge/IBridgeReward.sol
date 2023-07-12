// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IBridgeReward {
  struct BridgeRewardInfo {
    uint256 claimed;
    uint256 slashed;
  }

  /// @dev Event emitted when the reward per period config is updated.
  event UpdatedRewardPerPeriod(uint256 newRewardPerPeriod);
  /// @dev Event emitted when the reward of the `operator` is scattered with `amount`.
  event BridgeRewardScattered(address operator, uint256 amount);
  /// @dev Event emitted when the reward of the `operator` is slashed with `amount`.
  event BridgeRewardSlashed(address operator, uint256 amount);
  /// @dev Event emitted when the reward of the `operator` is scattered with `amount` but failed to transfer.
  event BridgeRewardScatterFailed(address operator, uint256 amount);

  function execSyncReward(
    address[] calldata operatorList,
    uint256[] calldata voteCountList,
    uint256 totalVoteCount,
    uint256 period
  ) external;

  function getRewardPerPeriod() external view returns (uint256);

  function setRewardPerPeriod(uint256 rewardPerPeriod) external;
}
