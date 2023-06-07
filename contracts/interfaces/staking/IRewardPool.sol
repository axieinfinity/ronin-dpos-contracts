// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../interfaces/consumers/PeriodWrapperConsumer.sol";

interface IRewardPool is PeriodWrapperConsumer {
  struct UserRewardFields {
    // Recorded reward amount.
    uint256 debited;
    // The last accumulated of the amount rewards per share (one unit staking) that the info updated.
    uint256 aRps;
    // Lowest staking amount in the period.
    uint256 lowestAmount;
    // Last period number that the info updated.
    uint256 lastPeriod;
  }

  struct PoolFields {
    // Accumulated of the amount rewards per share (one unit staking).
    uint256 aRps;
    // The staking total to share reward of the current period.
    PeriodWrapper shares;
  }

  /// @dev Emitted when the fields to calculate pending reward for the user is updated.
  event UserRewardUpdated(address indexed poolAddr, address indexed user, uint256 debited);
  /// @dev Emitted when the user claimed their reward
  event RewardClaimed(address indexed poolAddr, address indexed user, uint256 amount);

  /// @dev Emitted when the pool shares are updated
  event PoolSharesUpdated(uint256 indexed period, address indexed poolAddr, uint256 shares);
  /// @dev Emitted when the pools are updated
  event PoolsUpdated(uint256 indexed period, address[] poolAddrs, uint256[] aRps, uint256[] shares);
  /// @dev Emitted when the contract fails when updating the pools
  event PoolsUpdateFailed(uint256 indexed period, address[] poolAddrs, uint256[] rewards);
  /// @dev Emitted when the contract fails when updating the pools that already set
  event PoolsUpdateConflicted(uint256 indexed period, address[] poolAddrs);

  /// @dev Error of invalid pool share.
  error ErrInvalidPoolShare();

  /**
   * @dev Returns the reward amount that user claimable.
   */
  function getReward(address _poolAddr, address _user) external view returns (uint256);

  /**
   * @dev Returns the staking amount of an user.
   */
  function getStakingAmount(address _poolAddr, address _user) external view returns (uint256);

  /**
   * @dev Returns the staking amounts of the users.
   */
  function getManyStakingAmounts(
    address[] calldata _poolAddrs,
    address[] calldata _userList
  ) external view returns (uint256[] memory);

  /**
   * @dev Returns the total staking amount of all users for a pool.
   */
  function getStakingTotal(address _poolAddr) external view returns (uint256);

  /**
   * @dev Returns the total staking amounts of all users for the pools `_poolAddrs`.
   */
  function getManyStakingTotals(address[] calldata _poolAddrs) external view returns (uint256[] memory);
}
