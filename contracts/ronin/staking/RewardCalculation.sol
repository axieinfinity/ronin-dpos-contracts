// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../interfaces/IRewardPool.sol";
import "../../libraries/Math.sol";

/**
 * @title RewardCalculation contract
 * @dev This contract mainly contains the methods to calculate reward for staking contract.
 */
abstract contract RewardCalculation is IRewardPool {
  /// @dev Mapping from period => accumulated rewards per share (one unit staking)
  mapping(uint256 => uint256) private _accumulatedRpsAt;
  /// @dev Mapping from the pool address => user address => the reward info of the user
  mapping(address => mapping(address => UserRewardFields)) private _userReward;
  /// @dev Mapping from the pool address => staking pool data
  mapping(address => Pool) private _stakingPool;

  /**
   * @inheritdoc IRewardPool
   */
  function getReward(address _poolAddr, address _user) external view returns (uint256) {
    return _getReward(_poolAddr, _user, _currentPeriod(), stakingAmountOf(_poolAddr, _user));
  }

  /**
   * @inheritdoc IRewardPool
   */
  function stakingAmountOf(address _poolAddr, address _user) public view virtual returns (uint256);

  /**
   * @inheritdoc IRewardPool
   */
  function stakingTotal(address _poolAddr) public view virtual returns (uint256);

  /**
   * @dev Returns the reward amount that user claimable.
   */
  function _getReward(
    address _poolAddr,
    address _user,
    uint256 _latestPeriod,
    uint256 _latestStakingAmount
  ) internal view returns (uint256) {
    UserRewardFields storage _reward = _userReward[_poolAddr][_user];

    if (_reward.lastPeriod == _latestPeriod) {
      return _reward.debited;
    }

    Pool storage _pool = _stakingPool[_poolAddr];
    uint256 _minAmount = _reward.minAmount;
    uint256 _aRps = _accumulatedRpsAt[_reward.lastPeriod];
    uint256 _lastPeriodReward = _minAmount * (_aRps - _reward.aRps);
    uint256 _newPeriodsReward = _latestStakingAmount * (_pool.aRps - _aRps);
    return _reward.debited + (_lastPeriodReward + _newPeriodsReward) / 1e18;
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
    bool _sharesChanged;
    uint256 _period = _currentPeriod();
    Pool storage _pool = _stakingPool[_poolAddr];

    // The very first period will share equal to the current staking total amount
    if (_pool.lastPeriod == 0) {
      uint256 _stakingTotal = stakingTotal(_poolAddr);
      _sharesChanged = _pool.shares != _stakingTotal;
      if (_sharesChanged) {
        _pool.shares = _stakingTotal;
      }
    }

    UserRewardFields storage _reward = _userReward[_poolAddr][_user];
    uint256 _currentStakingAmount = stakingAmountOf(_poolAddr, _user);
    uint256 _debited = _getReward(_poolAddr, _user, _period, _currentStakingAmount);

    if (_reward.debited != _debited) {
      _reward.debited = _debited;
      emit UserRewardUpdated(_poolAddr, _user, _debited);
    }

    if (_sharesChanged || _syncMinStakingAmount(_pool, _reward, _period, _newStakingAmount, _currentStakingAmount)) {
      emit PoolSharesUpdated(_period, _poolAddr, _pool.shares);
    }

    _reward.aRps = _pool.aRps;
    _reward.lastPeriod = _period;
  }

  /**
   * @dev Syncs the minimum staking amount of an user in the current period.
   */
  function _syncMinStakingAmount(
    Pool storage _pool,
    UserRewardFields storage _reward,
    uint256 _latestPeriod,
    uint256 _newStakingAmount,
    uint256 _currentStakingAmount
  ) internal returns (bool _sharesChanged) {
    if (_reward.lastPeriod < _latestPeriod) {
      _reward.minAmount = _currentStakingAmount;
    }

    uint256 _minAmount = Math.min(_reward.minAmount, _newStakingAmount);
    uint256 _diffAmount = _reward.minAmount - _minAmount;
    _sharesChanged = _diffAmount > 0;
    if (_sharesChanged) {
      _reward.minAmount = _minAmount;
      require(_pool.shares >= _diffAmount, "RewardCalculation: invalid pool share");
      _pool.shares -= _diffAmount;
    }
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
    uint256 _latestPeriod = _currentPeriod();
    _amount = _getReward(_poolAddr, _user, _latestPeriod, stakingAmountOf(_poolAddr, _user));
    emit RewardClaimed(_poolAddr, _user, _amount);

    UserRewardFields storage _reward = _userReward[_poolAddr][_user];
    _reward.debited = 0;
    _reward.lastPeriod = _latestPeriod;
    _reward.aRps = _stakingPool[_poolAddr].aRps;
    emit UserRewardUpdated(_poolAddr, _user, 0);
  }

  /**
   * @dev Records the amount of rewards `_rewards` for the pools `_poolAddrs`.
   *
   * Emits the event `PoolsUpdated` once the contract recorded the rewards successfully.
   * Emits the event `PoolsUpdateFailed` once the input array lengths are not equal.
   * Emits the event `PoolUpdateConflicted` when the pool is already updated in the period.
   *
   * Note: This method should be called once at the period ending.
   *
   */
  function _recordRewards(
    uint256 _period,
    address[] calldata _poolAddrs,
    uint256[] calldata _rewards
  ) internal {
    if (_poolAddrs.length != _rewards.length) {
      emit PoolsUpdateFailed(_period, _poolAddrs, _rewards);
      return;
    }

    uint256 _rps;
    address _poolAddr;
    uint256 _stakingTotal;
    uint256[] memory _aRps = new uint256[](_poolAddrs.length);
    uint256[] memory _shares = new uint256[](_poolAddrs.length);

    for (uint _i = 0; _i < _poolAddrs.length; _i++) {
      _poolAddr = _poolAddrs[_i];
      Pool storage _pool = _stakingPool[_poolAddr];

      // Skips and emits event for the already set ones
      if (_pool.lastPeriod == _period) {
        _aRps[_i] = _pool.aRps;
        _shares[_i] = _pool.shares;
        emit PoolUpdateConflicted(_period, _poolAddr);
        continue;
      }

      _stakingTotal = stakingTotal(_poolAddr);
      // The very first period will share equal to the current staking total amount
      if (_pool.lastPeriod == 0) {
        _pool.shares = _stakingTotal;
      }

      // The rps is 0 if no one stakes for the pool
      _rps = _pool.shares == 0 ? 0 : (_rewards[_i] * 1e18) / _pool.shares;
      _aRps[_i] = _pool.aRps += _rps;
      _accumulatedRpsAt[_period] = _aRps[_i];
      _pool.lastPeriod = _period;
      if (_pool.shares != _stakingTotal) {
        _pool.shares = _stakingTotal;
      }
      _shares[_i] = _pool.shares;
    }

    emit PoolsUpdated(_period, _poolAddrs, _aRps, _shares);
  }

  /**
   * @dev Returns the current period.
   */
  function _currentPeriod() internal view virtual returns (uint256);
}
