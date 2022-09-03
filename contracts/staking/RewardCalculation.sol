// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

/**
 * @title RewardCalculation contract
 * @dev This contract mainly contains to calculate reward for staking contract.
 *
 * TODO(Thor): optimize gas cost when emitting SettledRewardUpdated and PendingRewardUpdated in the method `_claimReward`;
 *
 */
abstract contract RewardCalculation {
  /// @dev Emitted when the settled pool is updated.
  event SettledPoolUpdated(address poolAddress, uint256 accumulatedRps);
  /// @dev Emitted when the pending pool is updated.
  event PendingPoolUpdated(address poolAddress, uint256 accumulatedRps);
  /// @dev Emitted when the fields to calculate settled reward for the user is updated.
  event SettledRewardUpdated(
    address poolAddress,
    address user,
    uint256 balance,
    uint256 debited,
    uint256 accumulatedRps
  );
  /// @dev Emitted when the fields to calculate pending reward for the user is updated.
  event PendingRewardUpdated(address poolAddress, address user, uint256 debited, uint256 credited);
  /// @dev Emitted when the user claimed their reward
  event RewardClaimed(address poolAddress, address user, uint256 amount);

  struct PendingRewardFields {
    // Recorded reward amount.
    uint256 debited;
    // The amount rewards that user have already earned.
    uint256 credited;
    // Last block number that the info updated.
    uint256 lastSyncBlock;
  }

  struct SettledRewardFields {
    // The balance at the commit time.
    uint256 balance;
    // Recorded reward amount.
    uint256 debited;
    // Accumulated of the amount rewards per share (one unit staking).
    uint256 accumulatedRps;
  }

  struct PendingPool {
    // Last block number that the info updated.
    uint256 lastSyncBlock;
    // Accumulated of the amount rewards per share (one unit staking).
    uint256 accumulatedRps;
  }

  struct SettledPool {
    // Last block number that the info updated.
    uint256 lastSyncBlock;
    // Accumulated of the amount rewards per share (one unit staking).
    uint256 accumulatedRps;
  }

  /// @dev Mapping from the pool address => user address => settled reward info of the user
  mapping(address => mapping(address => SettledRewardFields)) internal _sUserReward;
  /// @dev Mapping from the pool address => user address => pending reward info of the user
  mapping(address => mapping(address => PendingRewardFields)) internal _pUserReward;

  /// @dev Mapping from the pool address => pending pool data
  mapping(address => PendingPool) internal _pendingPool;
  /// @dev Mapping from the pool address => settled pool data
  mapping(address => SettledPool) internal _settledPool;

  /**
   * @dev Returns total rewards from scratch including pending reward and claimable reward except the claimed amount.
   *
   * @notice Do not use this function to get claimable reward, consider using the method `getClaimableReward` instead.
   *
   */
  function getTotalReward(address _poolAddr, address _user) public view returns (uint256) {
    PendingRewardFields memory _reward = _pUserReward[_poolAddr][_user];
    PendingPool memory _pool = _pendingPool[_poolAddr];

    uint256 _balance = balanceOf(_poolAddr, _user);
    if (_slashed(_poolAddr, _periodOf(_reward.lastSyncBlock))) {
      SettledRewardFields memory _sReward = _sUserReward[_poolAddr][_user];
      uint256 _credited = (_sReward.accumulatedRps * _balance) / 1e18;
      return (_balance * _pool.accumulatedRps) / 1e18 + _sReward.debited - _credited;
    }

    return (_balance * _pool.accumulatedRps) / 1e18 + _reward.debited - _reward.credited;
  }

  /**
   * @dev Returns the reward amount that user claimable.
   */
  function getClaimableReward(address _poolAddr, address _user) public view returns (uint256) {
    PendingRewardFields memory _reward = _pUserReward[_poolAddr][_user];
    SettledRewardFields memory _sReward = _sUserReward[_poolAddr][_user];
    SettledPool memory _sPool = _settledPool[_poolAddr];

    if (_reward.lastSyncBlock <= _sPool.lastSyncBlock) {
      uint256 _currentBalance = balanceOf(_poolAddr, _user);
      _sReward.debited = (_currentBalance * _sPool.accumulatedRps) / 1e18 + _reward.debited - _reward.credited;
      _sReward.balance = _currentBalance;
      _sReward.accumulatedRps = _sPool.accumulatedRps;
    }

    uint256 _balance = _sReward.balance;
    uint256 _credited = (_balance * _sReward.accumulatedRps) / 1e18;
    return (_balance * _sPool.accumulatedRps) / 1e18 + _sReward.debited - _credited;
  }

  /**
   * @dev Returns the pending reward.
   */
  function getPendingReward(address _poolAddr, address _user) external view returns (uint256 _amount) {
    _amount = getTotalReward(_poolAddr, _user) - getClaimableReward(_poolAddr, _user);
  }

  /**
   * @dev Returns the staking amount of the user.
   */
  function balanceOf(address _poolAddr, address _user) public view virtual returns (uint256);

  /**
   * @dev Returns the total staking amount of all users.
   */
  function totalBalance(address _poolAddr) public view virtual returns (uint256);

  /**
   * @dev Syncs the user reward.
   *
   * Emits the `SettledRewardUpdated` event if the last block user made changes is recorded in the settled period.
   * Emits the `PendingRewardUpdated` event.
   *
   * @notice The method should be called whenever the user's balance changes.
   *
   */
  function _syncUserReward(
    address _poolAddr,
    address _user,
    uint256 _newBalance
  ) internal {
    PendingRewardFields storage _reward = _pUserReward[_poolAddr][_user];
    SettledPool memory _sPool = _settledPool[_poolAddr];

    // Syncs the reward once the last sync is settled.
    if (_reward.lastSyncBlock <= _sPool.lastSyncBlock) {
      uint256 _claimableReward = getClaimableReward(_poolAddr, _user);
      uint256 _balance = balanceOf(_poolAddr, _user);

      SettledRewardFields storage _sReward = _sUserReward[_poolAddr][_user];
      _sReward.balance = _balance;
      _sReward.debited = _claimableReward;
      _sReward.accumulatedRps = _sPool.accumulatedRps;
      emit SettledRewardUpdated(_poolAddr, _user, _balance, _claimableReward, _sPool.accumulatedRps);
    }

    PendingPool memory _pool = _pendingPool[_poolAddr];
    uint256 _debited = getTotalReward(_poolAddr, _user);
    uint256 _credited = (_newBalance * _pool.accumulatedRps) / 1e18;

    _reward.debited = _debited;
    _reward.credited = _credited;
    _reward.lastSyncBlock = block.number;
    emit PendingRewardUpdated(_poolAddr, _user, _debited, _credited);
  }

  /**
   * @dev Claims the settled reward for a specific user.
   *
   * Emits the `PendingRewardUpdated` event and the `SettledRewardUpdated` event.
   *
   * @notice This method should be called before transferring rewards for the user.
   *
   */
  function _claimReward(address _poolAddr, address _user) public returns (uint256 _amount) {
    _amount = getClaimableReward(_poolAddr, _user);
    emit RewardClaimed(_poolAddr, _user, _amount);
    SettledPool memory _sPool = _settledPool[_poolAddr];

    PendingRewardFields storage _reward = _pUserReward[_poolAddr][_user];
    _reward.credited += _amount;
    _reward.lastSyncBlock = block.number;
    emit PendingRewardUpdated(_poolAddr, _user, _reward.debited, _reward.credited);

    SettledRewardFields storage _sReward = _sUserReward[_poolAddr][_user];
    _sReward.debited = 0;
    _sReward.accumulatedRps = _sPool.accumulatedRps;
    emit SettledRewardUpdated(_poolAddr, _user, _sReward.balance, 0, _sPool.accumulatedRps);
  }

  /**
   * @dev Records the amount of reward `_reward` for the pending pool `_poolAddr`.
   *
   * Emits the `PendingPoolUpdated` event.
   *
   * @notice This method should not be called after the pool is slashed.
   *
   */
  function _recordReward(address _poolAddr, uint256 _reward) internal {
    PendingPool storage _pool = _pendingPool[_poolAddr];
    uint256 _accumulatedRps = _pool.accumulatedRps + (_reward * 1e18) / totalBalance(_poolAddr);
    _pool.accumulatedRps = _accumulatedRps;
    _pool.lastSyncBlock = block.number;
    emit PendingPoolUpdated(_poolAddr, _accumulatedRps);
  }

  /**
   * @dev Handles when the pool `_poolAddr` is slashed.
   *
   * Emits the `PendingPoolUpdated` event.
   *
   * @notice This method should be called when the pool is slashed.
   *
   */
  function _onSlashed(address _poolAddr) internal {
    uint256 _accumulatedRps = _settledPool[_poolAddr].accumulatedRps;
    PendingPool storage _pool = _pendingPool[_poolAddr];
    _pool.accumulatedRps = _accumulatedRps;
    _pool.lastSyncBlock = block.number;
    emit PendingPoolUpdated(_poolAddr, _accumulatedRps);
  }

  /**
   * @dev Handles when the pool `_poolAddr` is settled.
   *
   * Emits the `SettledPoolUpdated` event.
   *
   * @notice This method should be called once in the end of each period.
   *
   */
  function _onPoolSettled(address _poolAddr) internal {
    uint256 _accumulatedRps = _pendingPool[_poolAddr].accumulatedRps;
    SettledPool storage _sPool = _settledPool[_poolAddr];
    _sPool.accumulatedRps = _accumulatedRps;
    _sPool.lastSyncBlock = block.number;
    emit SettledPoolUpdated(_poolAddr, _accumulatedRps);
  }

  /**
   * @dev Returns whether the pool is slashed in the period `_period`.
   */
  function _slashed(address _poolAddr, uint256 _period) internal view virtual returns (bool);

  /**
   * @dev Returns the period from the block number.
   */
  function _periodOf(uint256 _block) internal view virtual returns (uint256);
}
