// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IRewardPool {
  /// @dev Emitted when a pool is updated.
  event PoolUpdated(address indexed poolAddr, uint256 accumulatedRps);
  /// @dev Emitted when the fields to calculate pending reward for the user is updated.
  event UserRewardUpdated(address indexed poolAddr, address indexed user, uint256 debited, uint256 credited);
  /// @dev Emitted when the user claimed their reward
  event RewardClaimed(address indexed poolAddr, address indexed user, uint256 amount);

  struct UserRewardFields {
    // Recorded reward amount.
    uint256 debited;
    // The amount rewards that user have already earned.
    uint256 credited;
    // Last period number that the info updated.
    uint256 lastSyncedPeriod;
    // Min staking amount in the period
    uint256 minStakingAmount;
  }

  struct Pool {
    // Accumulated of the amount rewards per share (one unit staking).
    uint256 accumulatedRps;
    // Last total staking amount of the previous period.
    uint256 lastTotalStaking;
  }

  /**
   * @dev Returns the reward amount that user claimable.
   */
  function getReward(address _poolAddr, address _user) external view returns (uint256);

  /**
   * @dev Returns the staking amount of an user.
   */
  function stakingAmountOf(address _poolAddr, address _user) external view returns (uint256);

  /**
   * @dev Returns the staking amounts of the users.
   */
  function bulkStakingAmountOf(address[] calldata _poolAddrs, address[] calldata _userList)
    external
    view
    returns (uint256[] memory);

  /**
   * @dev Returns the total staking amount of all users for a pool.
   */
  function stakingTotal(address _poolAddr) external view returns (uint256);

  /**
   * @dev Returns the total staking amounts of all users for the pools `_poolAddrs`.
   */
  function bulkStakingTotal(address[] calldata _poolAddrs) external view returns (uint256[] memory);
}
