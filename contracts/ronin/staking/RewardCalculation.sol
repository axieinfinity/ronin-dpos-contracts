// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../interfaces/staking/IRewardPool.sol";
import "../../libraries/Math.sol";

/**
 * @title RewardCalculation contract
 * @dev This contract mainly contains the methods to calculate reward for staking contract.
 */
abstract contract RewardCalculation is IRewardPool {
  /// @dev Mapping from pool address => period number => accumulated rewards per share (one unit staking)
  mapping(address => mapping(uint256 => PeriodWrapper)) private _accumulatedRps;
  /// @dev Mapping from the pool address => user address => the reward info of the user
  mapping(address => mapping(address => UserRewardFields)) private _userReward;
  /// @dev Mapping from the pool address => reward pool fields
  mapping(address => PoolFields) private _stakingPool;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private ______gap;

  /**
   * @inheritdoc IRewardPool
   */
  function getReward(address _poolAddr, address _user) external view returns (uint256) {
    return _getReward(_poolAddr, _user, _currentPeriod(), getStakingAmount(_poolAddr, _user));
  }

  /**
   * @inheritdoc IRewardPool
   */
  function getStakingAmount(address _poolAddr, address _user) public view virtual returns (uint256);

  /**
   * @inheritdoc IRewardPool
   */
  function getStakingTotal(address _poolAddr) public view virtual returns (uint256);

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

    uint256 _aRps;
    uint256 _lastPeriodReward;
    PoolFields storage _pool = _stakingPool[_poolAddr];
    PeriodWrapper storage _wrappedArps = _accumulatedRps[_poolAddr][_reward.lastPeriod];

    if (_wrappedArps.lastPeriod > 0) {
      // Calculates the last period reward if the aRps at the period is set
      _aRps = _wrappedArps.inner;
      _lastPeriodReward = _reward.lowestAmount * (_aRps - _reward.aRps);
    } else {
      // Fallbacks to the previous aRps in case the aRps is not set
      _aRps = _reward.aRps;
    }

    uint256 _newPeriodsReward = _latestStakingAmount * (_pool.aRps - _aRps);
    return _reward.debited + (_lastPeriodReward + _newPeriodsReward) / 1e18;
  }

  /**
   * @dev Syncs the user reward.
   *
   * Emits the event `UserRewardUpdated` once the debit amount is updated.
   * Emits the event `PoolSharesUpdated` once the pool share is updated.
   *
   * Note: The method should be called whenever the user's staking amount changes.
   *
   */
  function _syncUserReward(address _poolAddr, address _user, uint256 _newStakingAmount) internal {
    uint256 _period = _currentPeriod();
    PoolFields storage _pool = _stakingPool[_poolAddr];
    uint256 _lastShares = _pool.shares.inner;

    // Updates the pool shares if it is outdated
    if (_pool.shares.lastPeriod < _period) {
      _pool.shares = PeriodWrapper(getStakingTotal(_poolAddr), _period);
    }

    UserRewardFields storage _reward = _userReward[_poolAddr][_user];
    uint256 _currentStakingAmount = getStakingAmount(_poolAddr, _user);
    uint256 _debited = _getReward(_poolAddr, _user, _period, _currentStakingAmount);

    if (_reward.debited != _debited) {
      _reward.debited = _debited;
      emit UserRewardUpdated(_poolAddr, _user, _debited);
    }

    _syncMinStakingAmount(_pool, _reward, _period, _newStakingAmount, _currentStakingAmount);
    _reward.aRps = _pool.aRps;
    _reward.lastPeriod = _period;

    if (_pool.shares.inner != _lastShares) {
      emit PoolSharesUpdated(_period, _poolAddr, _pool.shares.inner);
    }
  }

  /**
   * @dev Syncs the minimum staking amount of an user in the current period.
   */
  function _syncMinStakingAmount(
    PoolFields storage _pool,
    UserRewardFields storage _reward,
    uint256 _latestPeriod,
    uint256 _newStakingAmount,
    uint256 _currentStakingAmount
  ) internal {
    if (_reward.lastPeriod < _latestPeriod) {
      _reward.lowestAmount = _currentStakingAmount;
    }

    uint256 _lowestAmount = Math.min(_reward.lowestAmount, _newStakingAmount);
    uint256 _diffAmount = _reward.lowestAmount - _lowestAmount;
    if (_diffAmount > 0) {
      _reward.lowestAmount = _lowestAmount;
      if (_pool.shares.inner < _diffAmount) revert ErrInvalidPoolShare();
      _pool.shares.inner -= _diffAmount;
    }
  }

  /**
   * @dev Claims the settled reward for a specific user.
   *
   * @param _lastPeriod Must be in two possible value: `_currentPeriod` in normal calculation, or
   * `_currentPeriod + 1` in case of calculating the reward for revoked validators.
   *
   * Emits the `RewardClaimed` event and the `UserRewardUpdated` event.
   *
   * Note: This method should be called before transferring rewards for the user.
   *
   */
  function _claimReward(address _poolAddr, address _user, uint256 _lastPeriod) internal returns (uint256 _amount) {
    uint256 _currentStakingAmount = getStakingAmount(_poolAddr, _user);
    _amount = _getReward(_poolAddr, _user, _lastPeriod, _currentStakingAmount);
    emit RewardClaimed(_poolAddr, _user, _amount);

    UserRewardFields storage _reward = _userReward[_poolAddr][_user];
    _reward.debited = 0;
    _syncMinStakingAmount(_stakingPool[_poolAddr], _reward, _lastPeriod, _currentStakingAmount, _currentStakingAmount);
    _reward.lastPeriod = _lastPeriod;
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
  function _recordRewards(address[] memory _poolAddrs, uint256[] calldata _rewards, uint256 _period) internal {
    if (_poolAddrs.length != _rewards.length) {
      emit PoolsUpdateFailed(_period, _poolAddrs, _rewards);
      return;
    }

    uint256 _rps;
    uint256 _count;
    address _poolAddr;
    uint256 _stakingTotal;
    uint256[] memory _aRps = new uint256[](_poolAddrs.length);
    uint256[] memory _shares = new uint256[](_poolAddrs.length);
    address[] memory _conflicted = new address[](_poolAddrs.length);

    for (uint _i = 0; _i < _poolAddrs.length; _i++) {
      _poolAddr = _poolAddrs[_i];
      PoolFields storage _pool = _stakingPool[_poolAddr];
      _stakingTotal = getStakingTotal(_poolAddr);

      if (_accumulatedRps[_poolAddr][_period].lastPeriod == _period) {
        unchecked {
          _conflicted[_count++] = _poolAddr;
        }
        continue;
      }

      // Updates the pool shares if it is outdated
      if (_pool.shares.lastPeriod < _period) {
        _pool.shares = PeriodWrapper(_stakingTotal, _period);
      }

      // The rps is 0 if no one stakes for the pool
      _rps = _pool.shares.inner == 0 ? 0 : (_rewards[_i] * 1e18) / _pool.shares.inner;
      _aRps[_i - _count] = _pool.aRps += _rps;
      _accumulatedRps[_poolAddr][_period] = PeriodWrapper(_pool.aRps, _period);
      _pool.shares.inner = _stakingTotal;
      _shares[_i - _count] = _pool.shares.inner;
      _poolAddrs[_i - _count] = _poolAddr;
    }

    if (_count > 0) {
      assembly {
        mstore(_conflicted, _count)
        mstore(_poolAddrs, sub(mload(_poolAddrs), _count))
      }
      emit PoolsUpdateConflicted(_period, _conflicted);
    }

    if (_poolAddrs.length > 0) {
      emit PoolsUpdated(_period, _poolAddrs, _aRps, _shares);
    }
  }

  /**
   * @dev Returns the current period.
   */
  function _currentPeriod() internal view virtual returns (uint256);
}
