// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "hardhat/console.sol";

abstract contract CoreStaking {
  struct UserRewardInfo {
    uint256 debited; // +
    uint256 credited; // -
    uint256 lastSyncBlock;
  }

  struct UserRewardInfoSnapshot {
    uint256 balance;
    uint256 debited; // +
    /// @dev Accumulated of the amount rewards per share (one unit staking).
    uint256 accumulatedRps;
  }

  struct StakingPool {
    uint256 lastSyncBlock;
    /// @dev Accumulated of the amount rewards per share (one unit staking).
    uint256 accumulatedRps;
  }

  struct StakingPoolSnapshot {
    uint256 lastSyncBlock;
    /// @dev Accumulated of the amount rewards per share (one unit staking).
    uint256 accumulatedRps;
  }

  mapping(address => UserRewardInfoSnapshot) internal _sUserReward;
  mapping(address => UserRewardInfo) internal _userReward;

  function _syncUserInfo(address _user, uint256 _newBalance) internal {
    UserRewardInfo storage _reward = _getUserRewardInfo(_user);
    StakingPoolSnapshot memory _sPool = _getStakingPoolSnapshot();

    uint256 _lastUserReward = getUserReward(_user);
    // Syncs the user reward snapshot once the last sync is committed (snapshotted).
    if (_reward.lastSyncBlock <= _sPool.lastSyncBlock) {
      UserRewardInfoSnapshot storage _sReward = _getUserRewardInfoSnapshot(_user);
      console.log("Synced for", _user, _lastUserReward, _sPool.accumulatedRps);
      _sReward.balance = getCurrentBalance(_user);
      _sReward.debited = _lastUserReward;
      _sReward.accumulatedRps = _sPool.accumulatedRps;
    }

    StakingPool memory _pool = _getStakingPool();
    _reward.debited = _lastUserReward;
    _reward.credited = (_newBalance * _pool.accumulatedRps) / 1e18;
    _reward.lastSyncBlock = block.number;
  }

  function getUserReward(address _user) public view returns (uint256) {
    UserRewardInfo memory _reward = _getUserRewardInfo(_user);
    StakingPool memory _pool = _getStakingPool();

    uint256 _balance = getCurrentBalance(_user);
    if (_slashed(_pool, _blockNumberToEpoch(_reward.lastSyncBlock))) {
      UserRewardInfoSnapshot memory _sReward = _getUserRewardInfoSnapshot(_user);
      return _getUserRewardOnSlashed(_sReward, _pool.accumulatedRps, _balance);
    }

    console.log("getUserReward:\t", _balance, _pool.accumulatedRps, _reward.debited);
    console.log("getUserReward:\t", _reward.credited);
    return (_balance * _pool.accumulatedRps) / 1e18 + _reward.debited - _reward.credited;
  }

  function _getUserRewardOnSlashed(
    UserRewardInfoSnapshot memory _sReward,
    uint256 _accumulatedRps,
    uint256 _balance
  ) internal pure returns (uint256) {
    uint256 _credited = (_sReward.accumulatedRps * _balance) / 1e18;
    return (_balance * _accumulatedRps) / 1e18 + _sReward.debited - _credited;
  }

  function _getUserRewardInfo(address _user) internal view virtual returns (UserRewardInfo storage) {
    return _userReward[_user];
  }

  function _getUserRewardInfoSnapshot(address _user) internal view virtual returns (UserRewardInfoSnapshot storage) {
    return _sUserReward[_user];
  }

  function _slashed(StakingPool memory, uint256) internal view virtual returns (bool) {}

  function _blockNumberToEpoch(uint256) internal view virtual returns (uint256) {}

  function _getStakingPool() internal view virtual returns (StakingPool memory) {}

  function _getStakingPoolSnapshot() internal view virtual returns (StakingPoolSnapshot memory) {}

  function getCurrentBalance(address) public view virtual returns (uint256) {}
}
