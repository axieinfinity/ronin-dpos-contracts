// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../interfaces/IRewardPool.sol";
import "../../libraries/Math.sol";

/**
 * @title RewardCalculation contract
 * @dev This contract mainly contains the methods to calculate reward for staking contract.
 */
abstract contract RewardCalculation is IRewardPool {
  /// @dev Mapping from the pool address => staking pool data
  mapping(address => Pool) internal _stakingPool;
  /// @dev Mapping from the pool address => user address => the reward info of the user
  mapping(address => mapping(address => UserRewardFields)) internal _userReward;

  /**
   * @inheritdoc IRewardPool
   */
  function getReward(address _poolAddr, address _user) external view returns (uint256) {
    return _getReward(_poolAddr, _user, _currentPeriod());
  }

  /**
   * @inheritdoc IRewardPool
   */
  function stakingAmountOf(address _poolAddr, address _user) public view virtual returns (uint256);

  /**
   * @inheritdoc IRewardPool
   */
  function stakingTotal(address _poolAddr) public view virtual returns (uint256);

  function _getReward(
    address _poolAddr,
    address _user,
    uint256 _latestPeriod
  ) internal view returns (uint256) {
    Pool storage _pool = _stakingPool[_poolAddr];
    UserRewardFields storage _reward = _userReward[_poolAddr][_user];

    uint256 _amount;
    if (_reward.lastSyncedPeriod < _latestPeriod) {
      _amount = stakingAmountOf(_poolAddr, _user);
    } else if (_reward.lastSyncedPeriod == _latestPeriod) {
      _amount = _reward.minStakingAmount;
    }

    return (_amount * _pool.accumulatedRps) / 1e18 + _reward.debited - _reward.credited;
  }

  /**
   * @dev Syncs the user reward.
   *
   * Emits the `UserRewardUpdated` event.
   *
   * Note: The method should be called whenever the user's staking amount changes.
   *
   */
  function _syncUserReward(
    address _poolAddr,
    address _user,
    uint256 _newStakingAmount
  ) internal {
    UserRewardFields storage _reward = _userReward[_poolAddr][_user];
    Pool storage _pool = _stakingPool[_poolAddr];
    uint256 _period = _currentPeriod();

    if (_reward.lastSyncedPeriod <= _period) {
      _reward.minStakingAmount = _newStakingAmount;
    }

    uint256 _minStakingAmount = Math.min(_reward.minStakingAmount, _newStakingAmount);
    uint256 _diffAmount = _reward.minStakingAmount - _minStakingAmount;
    if (_diffAmount > 0) {
      require(_pool.lastTotalStaking >= _diffAmount, "Code bug"); // TODO: remove this
      _pool.lastTotalStaking -= _diffAmount;
    }
    _reward.minStakingAmount = _minStakingAmount;

    uint256 _debited = _getReward(_poolAddr, _user, _period);
    // NOTE: becareful calculating `_credited`
    uint256 _credited = (_newStakingAmount * _pool.accumulatedRps) / 1e18;
    _reward.debited = _debited;
    _reward.credited = _credited;
    _reward.lastSyncedPeriod = _period;

    emit UserRewardUpdated(_poolAddr, _user, _debited, _credited);
  }

  /**
   * @dev Claims the settled reward for a specific user.
   *
   * Emits the `PendingRewardUpdated` event and the `SettledRewardUpdated` event.
   *
   * Note: This method should be called before transferring rewards for the user.
   *
   */
  function _claimReward(address _poolAddr, address _user) internal returns (uint256 _amount) {
    _amount = getReward(_poolAddr, _user);
    emit RewardClaimed(_poolAddr, _user, _amount);

    UserRewardFields storage _reward = _userReward[_poolAddr][_user];
    _reward.debited = 0;
    _reward.credited += _amount;
    _reward.lastSyncedPeriod = _currentPeriod();
    emit UserRewardUpdated(_poolAddr, _user, _reward.debited, _reward.credited);
  }

  /**
   * @dev Records the amount of reward `_reward` for the pending pool `_poolAddr`.
   *
   * Emits the `PoolUpdated` event.
   *
   * Note: This method should be called once period ending.
   *
   */
  function _recordReward(address _poolAddr, uint256 _reward) internal {
    Pool storage _pool = _stakingPool[_poolAddr];
    uint256 _accumulatedRps = _pool.accumulatedRps + (_reward * 1e18) / _pool.lastTotalStaking;
    _pool.accumulatedRps = _accumulatedRps;
    emit PoolUpdated(_poolAddr, _accumulatedRps);
    _pool.lastTotalStaking = stakingTotal(_poolAddr);
  }

  /**
   * @dev Returns the current period.
   */
  function _currentPeriod() internal view virtual returns (uint256);
}
