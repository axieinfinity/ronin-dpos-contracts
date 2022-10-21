// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IRewardPool {
  /// @dev Emitted when the settled pool is updated.
  event SettledPoolsUpdated(address[] poolAddress, uint256[] accumulatedRps);
  /// @dev Emitted when the pending pool is updated.
  event PendingPoolUpdated(address poolAddress, uint256 accumulatedRps);
  /// @dev Emitted when the fields to calculate settled reward for the user is updated.
  event SettledRewardUpdated(address poolAddress, address user, uint256 debited, uint256 accumulatedRps);
  /// @dev Emitted when the fields to calculate pending reward for the user is updated.
  event PendingRewardUpdated(address poolAddress, address user, uint256 debited, uint256 credited);
  /// @dev Emitted when the user claimed their reward
  event RewardClaimed(address poolAddress, address user, uint256 amount);

  struct PendingRewardFields {
    // Recorded reward amount.
    uint256 debited;
    // The amount rewards that user have already earned.
    uint256 credited;
    // Last period number that the info updated.
    uint256 lastSyncedPeriod;
  }

  struct SettledRewardFields {
    // Recorded reward amount.
    uint256 debited;
    // Accumulated of the amount rewards per share (one unit staking).
    uint256 accumulatedRps;
  }

  struct PendingPool {
    // Accumulated of the amount rewards per share (one unit staking).
    uint256 accumulatedRps;
  }

  struct SettledPool {
    // Last period number that the info updated.
    uint256 lastSyncedPeriod;
    // Accumulated of the amount rewards per share (one unit staking).
    uint256 accumulatedRps;
  }

  /**
   * @dev Returns total rewards from scratch including pending reward and claimable reward except the claimed amount.
   *
   * Note: Do not use this function to get claimable reward, consider using the method `getClaimableReward` instead.
   *
   */
  function getTotalReward(address _poolAddr, address _user) external view returns (uint256);

  /**
   * @dev Returns the reward amount that user claimable.
   */
  function getClaimableReward(address _poolAddr, address _user) external view returns (uint256);

  /**
   * @dev Returns the pending reward.
   */
  function getPendingReward(address _poolAddr, address _user) external view returns (uint256 _amount);

  /**
   * @dev Returns the staked amount of the user.
   */
  function balanceOf(address _poolAddr, address _user) external view returns (uint256);

  /**
   * @dev Returns the staked amounts of the users.
   */
  function bulkBalanceOf(address[] calldata _poolAddrs, address[] calldata _userList)
    external
    view
    returns (uint256[] memory);

  /**
   * @dev Returns the total staked amount of all users.
   */
  function totalBalance(address _poolAddr) external view returns (uint256);

  /**
   * @dev Returns the total staked amount of all users.
   */
  function totalBalances(address[] calldata _poolAddr) external view returns (uint256[] memory);
}
