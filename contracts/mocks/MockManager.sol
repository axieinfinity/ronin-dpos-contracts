// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "../staking/CoreStaking.sol";

contract MockManager is CoreStaking {
  /// @dev Mapping from user => staking balance
  mapping(address => uint256) internal _stakingBalance;
  /// @dev Mapping from epoch number => slashed
  mapping(uint256 => bool) internal _epochSlashed;

  uint256[] internal _epoches;

  uint256 public totalBalance;

  StakingPool public pool;
  StakingPoolSnapshot public poolSnapshot;

  constructor() {
    _epoches.push(0);
  }

  function endEpoch() external {
    _epoches.push(block.number);
  }

  function stake(address _user, uint256 _amount) external {
    uint256 _balance = _stakingBalance[_user];
    uint256 _newBalance = _balance + _amount;
    _syncUserInfo(_user, _newBalance);
    _stakingBalance[_user] = _newBalance;
    totalBalance += _amount;
  }

  function unstake(address _user, uint256 _amount) external {
    uint256 _balance = _stakingBalance[_user];
    uint256 _newBalance = _balance - _amount;
    _syncUserInfo(_user, _newBalance);
    _stakingBalance[_user] = _newBalance;
    totalBalance -= _amount;
  }

  function recordReward(uint256 _rewardAmount) public {
    increaseAccumulatedRps((_rewardAmount * 1e18) / totalBalance);
  }

  function commitRewardPool() public {
    StakingPoolSnapshot storage _sPool = poolSnapshot;
    _sPool.accumulatedRps = pool.accumulatedRps;
    _sPool.lastSyncBlock = block.number;
  }

  function increaseAccumulatedRps(uint256 _amount) public {
    pool.accumulatedRps += _amount;
    pool.lastSyncBlock = block.number;
  }

  function increaseAndSyncSnapshot(uint256 _amount) external {
    increaseAccumulatedRps(_amount);
    poolSnapshot.accumulatedRps = pool.accumulatedRps;
    poolSnapshot.lastSyncBlock = block.number;
  }

  function slash() external {
    uint256 _epoch = getEpoch();
    console.log("Slash block=", block.number, "at epoch=", _epoch);
    _epochSlashed[_epoch] = true;
    pool.accumulatedRps = poolSnapshot.accumulatedRps;
    pool.lastSyncBlock = block.number;
  }

  function getEpoch() public view returns (uint256) {
    return _blockNumberToEpoch(block.number);
  }

  function claimReward(address _user) public returns (uint256 _amount) {
    uint256 _balance = getCurrentBalance(_user);
    _amount = getClaimableReward(_user);
    StakingPoolSnapshot memory _sPool = _getStakingPoolSnapshot();
    console.log("User", _user, "claimed", _amount);

    UserRewardInfo storage _reward = _getUserRewardInfo(_user);
    console.log("claimReward: \t =>", _reward.debited);
    _reward.debited = 0;
    _reward.credited = (_balance * _sPool.accumulatedRps) / 1e18;
    _reward.lastSyncBlock = block.number;
    console.log("claimReward: \t", _balance, _sPool.accumulatedRps);

    UserRewardInfoSnapshot storage _sReward = _getUserRewardInfoSnapshot(_user);
    _sReward.debited = 0;
    _sReward.accumulatedRps = _sPool.accumulatedRps;
  }

  function getClaimableReward(address _user) public view returns (uint256) {
    UserRewardInfo memory _reward = _getUserRewardInfo(_user);
    UserRewardInfoSnapshot memory _sReward = _getUserRewardInfoSnapshot(_user);
    StakingPoolSnapshot memory _sPool = _getStakingPoolSnapshot();

    console.log("-> getClaimableReward", _reward.lastSyncBlock, _sPool.lastSyncBlock);
    if (_reward.lastSyncBlock <= _sPool.lastSyncBlock) {
      console.log("\t-> sync");
      _sReward.debited = (getCurrentBalance(_user) * _sPool.accumulatedRps) / 1e18 + _reward.debited - _reward.credited;
      _sReward.balance = getCurrentBalance(_user);
      _sReward.accumulatedRps = _sPool.accumulatedRps;
    }

    uint256 _balance = _sReward.balance;
    uint256 _credited = (_balance * _sReward.accumulatedRps) / 1e18;
    console.log("\t", _balance, _sReward.accumulatedRps, _sPool.accumulatedRps);
    console.log("\t", _sReward.debited);
    return (_balance * _sPool.accumulatedRps) / 1e18 + _sReward.debited - _credited;
  }

  function _slashed(StakingPool memory, uint256 _epoch) internal view override returns (bool) {
    return _epochSlashed[_epoch];
  }

  function _blockNumberToEpoch(uint256 _block) internal view override returns (uint256 _epoch) {
    for (uint256 _i; _i < _epoches.length; _i++) {
      if (_block >= _epoches[_i]) {
        _epoch = _i + 1;
      }
    }
  }

  function _getStakingPool() internal view override returns (StakingPool memory) {
    return pool;
  }

  function _getStakingPoolSnapshot() internal view override returns (StakingPoolSnapshot memory) {
    return poolSnapshot;
  }

  function getCurrentBalance(address _user) public view override returns (uint256) {
    return _stakingBalance[_user];
  }
}
