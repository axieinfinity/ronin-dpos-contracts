// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../interfaces/IRewardPool.sol";

/**
 * @title RewardCalculation contract
 * @dev This contract mainly contains to calculate reward for staking contract.
 */
abstract contract RewardCalculation is IRewardPool {
  /// @dev Mapping from the pool address => user address => settled reward info of the user
  mapping(address => mapping(address => SettledRewardFields)) internal _sUserReward;
  /// @dev Mapping from the pool address => user address => pending reward info of the user
  mapping(address => mapping(address => PendingRewardFields)) internal _pUserReward;

  /// @dev Mapping from the pool address => pending pool data
  mapping(address => PendingPool) internal _pendingPool;
  /// @dev Mapping from the pool address => settled pool data
  mapping(address => SettledPool) internal _settledPool;

  /**
   * @inheritdoc IRewardPool
   */
  function getTotalReward(address _poolAddr, address _user) public view returns (uint256) {
    PendingRewardFields memory _reward = _pUserReward[_poolAddr][_user];
    PendingPool memory _pool = _pendingPool[_poolAddr];

    uint256 _balance = balanceOf(_poolAddr, _user);
    if (_rewardSinked(_poolAddr, _periodOf(_reward.lastSyncedBlock))) {
      SettledRewardFields memory _sReward = _sUserReward[_poolAddr][_user];
      uint256 _credited = (_sReward.accumulatedRps * _balance) / 1e18;
      return (_balance * _pool.accumulatedRps) / 1e18 + _sReward.debited - _credited;
    }

    return (_balance * _pool.accumulatedRps) / 1e18 + _reward.debited - _reward.credited;
  }

  /**
   * @inheritdoc IRewardPool
   */
  function getClaimableReward(address _poolAddr, address _user) public view returns (uint256) {
    PendingRewardFields memory _reward = _pUserReward[_poolAddr][_user];
    SettledRewardFields memory _sReward = _sUserReward[_poolAddr][_user];
    SettledPool memory _sPool = _settledPool[_poolAddr];

    if (_reward.lastSyncedBlock <= _sPool.lastSyncedBlock) {
      uint256 _currentBalance = balanceOf(_poolAddr, _user);
      return (_currentBalance * _sPool.accumulatedRps) / 1e18 + _reward.debited - _reward.credited;
    }

    uint256 _diffRps = _sPool.accumulatedRps - _sReward.accumulatedRps;
    return (_sReward.balance * _diffRps) / 1e18 + _sReward.debited;
  }

  /**
   * @inheritdoc IRewardPool
   */
  function getPendingReward(address _poolAddr, address _user) external view returns (uint256 _amount) {
    _amount = getTotalReward(_poolAddr, _user) - getClaimableReward(_poolAddr, _user);
  }

  /**
   * @inheritdoc IRewardPool
   */
  function balanceOf(address _poolAddr, address _user) public view virtual returns (uint256);

  /**
   * @inheritdoc IRewardPool
   */
  function totalBalance(address _poolAddr) public view virtual returns (uint256);

  /**
   * @dev Syncs the user reward.
   *
   * Emits the `SettledRewardUpdated` event if the last block user made changes is recorded in the settled period.
   * Emits the `PendingRewardUpdated` event.
   *
   * Note: The method should be called whenever the user's balance changes.
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
    if (_reward.lastSyncedBlock <= _sPool.lastSyncedBlock) {
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
    _reward.lastSyncedBlock = block.number;
    emit PendingRewardUpdated(_poolAddr, _user, _debited, _credited);
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
    _amount = getClaimableReward(_poolAddr, _user);
    emit RewardClaimed(_poolAddr, _user, _amount);

    SettledPool memory _sPool = _settledPool[_poolAddr];
    PendingRewardFields storage _reward = _pUserReward[_poolAddr][_user];
    SettledRewardFields storage _sReward = _sUserReward[_poolAddr][_user];

    _sReward.debited = 0;
    if (_reward.lastSyncedBlock <= _sPool.lastSyncedBlock) {
      _sReward.balance = balanceOf(_poolAddr, _user);
      _sReward.accumulatedRps = _sPool.accumulatedRps;
    }
    emit SettledRewardUpdated(_poolAddr, _user, _sReward.balance, 0, _sReward.accumulatedRps);

    _reward.credited += _amount;
    _reward.lastSyncedBlock = block.number;
    emit PendingRewardUpdated(_poolAddr, _user, _reward.debited, _reward.credited);
  }

  /**
   * @dev Records the amount of reward `_reward` for the pending pool `_poolAddr`.
   *
   * Emits the `PendingPoolUpdated` event.
   *
   * Note: This method should not be called after the pending pool is sinked.
   *
   */
  function _recordReward(address _poolAddr, uint256 _reward) internal {
    PendingPool storage _pool = _pendingPool[_poolAddr];
    uint256 _accumulatedRps = _pool.accumulatedRps + (_reward * 1e18) / totalBalance(_poolAddr);
    _pool.accumulatedRps = _accumulatedRps;
    emit PendingPoolUpdated(_poolAddr, _accumulatedRps);
  }

  /**
   * @dev Handles when the pool `_poolAddr` is sinked.
   *
   * Emits the `PendingPoolUpdated` event.
   *
   * Note: This method should be called when the pool is sinked.
   *
   */
  function _sinkPendingReward(address _poolAddr) internal {
    uint256 _accumulatedRps = _settledPool[_poolAddr].accumulatedRps;
    PendingPool storage _pool = _pendingPool[_poolAddr];
    _pool.accumulatedRps = _accumulatedRps;
    emit PendingPoolUpdated(_poolAddr, _accumulatedRps);
  }

  /**
   * @dev Handles when the pool `_poolAddr` is settled.
   *
   * Emits the `SettledPoolsUpdated` event.
   *
   * Note: This method should be called once in the end of each period.
   *
   */
  function _onPoolsSettled(address[] calldata _poolList) internal {
    uint256[] memory _accumulatedRpsList = new uint256[](_poolList.length);
    address _poolAddr;
    for (uint256 _i; _i < _poolList.length; _i++) {
      _poolAddr = _poolList[_i];
      _accumulatedRpsList[_i] = _pendingPool[_poolAddr].accumulatedRps;

      SettledPool storage _sPool = _settledPool[_poolAddr];
      _sPool.accumulatedRps = _accumulatedRpsList[_i];
      _sPool.lastSyncedBlock = block.number;
    }
    emit SettledPoolsUpdated(_poolList, _accumulatedRpsList);
  }

  /**
   * @dev Returns whether the pool is slashed in the period `_period`.
   */
  function _rewardSinked(address _poolAddr, uint256 _period) internal view virtual returns (bool);

  /**
   * @dev Returns the period from the block number.
   */
  function _periodOf(uint256 _block) internal view virtual returns (uint256);
}
