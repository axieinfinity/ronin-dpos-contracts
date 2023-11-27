// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../interfaces/staking/IRewardPool.sol";
import "../../libraries/Math.sol";
import { TPoolId } from "../../udvts/Types.sol";

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
  function getReward(TConsensus consensusAddr, address user) external view returns (uint256) {
    address poolId = TConsensus.unwrap(consensusAddr);
    return _getReward(poolId, user, _currentPeriod(), _getStakingAmount(poolId, user));
  }

  /**
   * @dev See {IRewardPool-getStakingAmount}
   */
  function _getStakingAmount(address poolId, address user) internal view virtual returns (uint256);

  /**
   * @dev See {IRewardPool-getStakingTotal}
   */
  function _getStakingTotal(address poolId) internal view virtual returns (uint256);

  /**
   * @dev Returns the reward amount that user claimable.
   */
  function _getReward(
    address poolId,
    address user,
    uint256 latestPeriod,
    uint256 latestStakingAmount
  ) internal view returns (uint256) {
    UserRewardFields storage _reward = _userReward[poolId][user];

    if (_reward.lastPeriod == latestPeriod) {
      return _reward.debited;
    }

    uint256 aRps;
    uint256 lastPeriodReward;
    PoolFields storage _pool = _stakingPool[poolId];
    PeriodWrapper storage _wrappedArps = _accumulatedRps[poolId][_reward.lastPeriod];

    if (_wrappedArps.lastPeriod > 0) {
      // Calculates the last period reward if the aRps at the period is set
      aRps = _wrappedArps.inner;
      lastPeriodReward = _reward.lowestAmount * (aRps - _reward.aRps);
    } else {
      // Fallbacks to the previous aRps in case the aRps is not set
      aRps = _reward.aRps;
    }

    uint256 newPeriodsReward = latestStakingAmount * (_pool.aRps - aRps);
    return _reward.debited + (lastPeriodReward + newPeriodsReward) / 1e18;
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
  function _syncUserReward(address poolId, address user, uint256 newStakingAmount) internal {
    uint256 period = _currentPeriod();
    PoolFields storage _pool = _stakingPool[poolId];
    uint256 lastShares = _pool.shares.inner;

    // Updates the pool shares if it is outdated
    if (_pool.shares.lastPeriod < period) {
      _pool.shares = PeriodWrapper(_getStakingTotal(poolId), period);
    }

    UserRewardFields storage _reward = _userReward[poolId][user];
    uint256 currentStakingAmount = _getStakingAmount(poolId, user);
    uint256 debited = _getReward(poolId, user, period, currentStakingAmount);

    if (_reward.debited != debited) {
      _reward.debited = debited;
      emit UserRewardUpdated(poolId, user, debited);
    }

    _syncMinStakingAmount(_pool, _reward, period, newStakingAmount, currentStakingAmount);
    _reward.aRps = _pool.aRps;
    _reward.lastPeriod = period;

    if (_pool.shares.inner != lastShares) {
      emit PoolSharesUpdated(period, poolId, _pool.shares.inner);
    }
  }

  /**
   * @dev Syncs the minimum staking amount of an user in the current period.
   */
  function _syncMinStakingAmount(
    PoolFields storage _pool,
    UserRewardFields storage _reward,
    uint256 latestPeriod,
    uint256 newStakingAmount,
    uint256 currentStakingAmount
  ) internal {
    if (_reward.lastPeriod < latestPeriod) {
      _reward.lowestAmount = currentStakingAmount;
    }

    uint256 lowestAmount = Math.min(_reward.lowestAmount, newStakingAmount);
    uint256 diffAmount = _reward.lowestAmount - lowestAmount;
    if (diffAmount > 0) {
      _reward.lowestAmount = lowestAmount;
      if (_pool.shares.inner < diffAmount) revert ErrInvalidPoolShare();
      _pool.shares.inner -= diffAmount;
    }
  }

  /**
   * @dev Claims the settled reward for a specific user.
   *
   * @param lastPeriod Must be in two possible value: `_currentPeriod` in normal calculation, or
   * `_currentPeriod + 1` in case of calculating the reward for revoked validators.
   *
   * Emits the `RewardClaimed` event and the `UserRewardUpdated` event.
   *
   * Note: This method should be called before transferring rewards for the user.
   *
   */
  function _claimReward(address poolId, address user, uint256 lastPeriod) internal returns (uint256 amount) {
    uint256 currentStakingAmount = _getStakingAmount(poolId, user);
    amount = _getReward(poolId, user, lastPeriod, currentStakingAmount);
    emit RewardClaimed(poolId, user, amount);

    UserRewardFields storage _reward = _userReward[poolId][user];
    _reward.debited = 0;
    _syncMinStakingAmount(_stakingPool[poolId], _reward, lastPeriod, currentStakingAmount, currentStakingAmount);
    _reward.lastPeriod = lastPeriod;
    _reward.aRps = _stakingPool[poolId].aRps;
    emit UserRewardUpdated(poolId, user, 0);
  }

  /**
   * @dev Records the amount of rewards `_rewards` for the pools `poolIds`.
   *
   * Emits the event `PoolsUpdated` once the contract recorded the rewards successfully.
   * Emits the event `PoolsUpdateFailed` once the input array lengths are not equal.
   * Emits the event `PoolUpdateConflicted` when the pool is already updated in the period.
   *
   * Note: This method should be called once at the period ending.
   *
   */
  function _recordRewards(address[] memory poolIds, uint256[] calldata rewards, uint256 period) internal {
    if (poolIds.length != rewards.length) {
      emit PoolsUpdateFailed(period, poolIds, rewards);
      return;
    }

    uint256 rps;
    uint256 count;
    address poolId;
    uint256 stakingTotal;
    uint256[] memory aRps = new uint256[](poolIds.length);
    uint256[] memory shares = new uint256[](poolIds.length);
    address[] memory conflicted = new address[](poolIds.length);

    for (uint i = 0; i < poolIds.length; i++) {
      poolId = poolIds[i];
      PoolFields storage _pool = _stakingPool[poolId];
      stakingTotal = _getStakingTotal(poolId);

      if (_accumulatedRps[poolId][period].lastPeriod == period) {
        unchecked {
          conflicted[count++] = poolId;
        }
        continue;
      }

      // Updates the pool shares if it is outdated
      if (_pool.shares.lastPeriod < period) {
        _pool.shares = PeriodWrapper(stakingTotal, period);
      }

      // The rps is 0 if no one stakes for the pool
      rps = _pool.shares.inner == 0 ? 0 : (rewards[i] * 1e18) / _pool.shares.inner;
      aRps[i - count] = _pool.aRps += rps;
      _accumulatedRps[poolId][period] = PeriodWrapper(_pool.aRps, period);
      _pool.shares.inner = stakingTotal;
      shares[i - count] = _pool.shares.inner;
      poolIds[i - count] = poolId;
    }

    if (count > 0) {
      assembly {
        mstore(conflicted, count)
        mstore(poolIds, sub(mload(poolIds), count))
      }
      emit PoolsUpdateConflicted(period, conflicted);
    }

    if (poolIds.length > 0) {
      emit PoolsUpdated(period, poolIds, aRps, shares);
    }
  }

  /**
   * @dev Returns the current period.
   */
  function _currentPeriod() internal view virtual returns (uint256);
}
