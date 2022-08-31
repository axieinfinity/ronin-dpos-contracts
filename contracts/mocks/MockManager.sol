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

  PendingPool public pool;
  SettledPool public sPool;

  constructor() {
    _epoches.push(0);
  }

  function endEpoch() external {
    _epoches.push(block.number);
  }

  function stake(address _user, uint256 _amount) external {
    uint256 _balance = _stakingBalance[_user];
    uint256 _newBalance = _balance + _amount;
    _syncUserReward(_user, _newBalance);
    _stakingBalance[_user] = _newBalance;
    totalBalance += _amount;
  }

  function unstake(address _user, uint256 _amount) external {
    uint256 _balance = _stakingBalance[_user];
    uint256 _newBalance = _balance - _amount;
    _syncUserReward(_user, _newBalance);
    _stakingBalance[_user] = _newBalance;
    totalBalance -= _amount;
  }

  function recordReward(uint256 _rewardAmount) public {
    increaseAccumulatedRps((_rewardAmount * 1e18) / totalBalance);
  }

  function commitRewardPool() public {
    SettledPool storage _sPool = sPool;
    _sPool.accumulatedRps = pool.accumulatedRps;
    _sPool.lastSyncBlock = block.number;
  }

  function increaseAccumulatedRps(uint256 _amount) public {
    pool.accumulatedRps += _amount;
    pool.lastSyncBlock = block.number;
  }

  function increaseAndSyncSnapshot(uint256 _amount) external {
    increaseAccumulatedRps(_amount);
    sPool.accumulatedRps = pool.accumulatedRps;
    sPool.lastSyncBlock = block.number;
  }

  function slash() external {
    uint256 _epoch = getEpoch();
    console.log("Slash block=", block.number, "at epoch=", _epoch);
    _epochSlashed[_epoch] = true;
    pool.accumulatedRps = sPool.accumulatedRps;
    pool.lastSyncBlock = block.number;
  }

  function getEpoch() public view returns (uint256) {
    return _blockNumberToEpoch(block.number);
  }

  function claimReward(address _user) public returns (uint256 _amount) {
    uint256 _balance = balanceOf(_user);
    _amount = getClaimableReward(_user);
    SettledPool memory _sPool = _getSettledPool();
    // PendingPool memory _pool = _getStakingPool();
    console.log("User", _user, "claimed", _amount);

    PendingRewardFields storage _reward = _getPendingRewardFields(_user);
    console.log("claimReward: \t => (+)=", _reward.debited, _reward.debited);
    console.log("claimReward: \t => (-)=", _reward.credited, _reward.credited + _amount);
    // _reward.debited = 0;
    _reward.credited += _amount;
    _reward.lastSyncBlock = block.number;
    console.log("claimReward: \t", _balance, _sPool.accumulatedRps);

    SettledRewardFields storage _sReward = _getSettledRewardFields(_user);
    _sReward.debited = 0;
    _sReward.accumulatedRps = _sPool.accumulatedRps;
  }

  function _slashed(PendingPool memory, uint256 _epoch) internal view override returns (bool) {
    return _epochSlashed[_epoch];
  }

  function _blockNumberToEpoch(uint256 _block) internal view override returns (uint256 _epoch) {
    for (uint256 _i; _i < _epoches.length; _i++) {
      if (_block >= _epoches[_i]) {
        _epoch = _i + 1;
      }
    }
  }

  function _getPendingPool() internal view override returns (PendingPool memory) {
    return pool;
  }

  function _getSettledPool() internal view override returns (SettledPool memory) {
    return sPool;
  }

  function balanceOf(address _user) public view override returns (uint256) {
    return _stakingBalance[_user];
  }
}
