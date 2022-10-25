// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../ronin/staking/RewardCalculation.sol";

contract MockStaking is RewardCalculation {
  /// @dev Mapping from user => staking balance
  mapping(address => uint256) internal _stakingBalance;
  /// @dev Mapping from period number => slashed
  mapping(uint256 => bool) internal _periodSlashed;
  uint256 internal _lastUpdatedPeriod;
  uint256 internal _totalBalance;

  address public poolAddr;

  constructor(address _poolAddr) {
    _lastUpdatedPeriod++;
    poolAddr = _poolAddr;
  }

  function endPeriod() external {
    _lastUpdatedPeriod++;
  }

  function stake(address _user, uint256 _amount) external {
    uint256 _balance = _stakingBalance[_user];
    uint256 _newBalance = _balance + _amount;
    _syncUserReward(poolAddr, _user, _newBalance);
    _stakingBalance[_user] = _newBalance;
    _totalBalance += _amount;
  }

  function unstake(address _user, uint256 _amount) external {
    uint256 _balance = _stakingBalance[_user];
    uint256 _newBalance = _balance - _amount;
    _syncUserReward(poolAddr, _user, _newBalance);
    _stakingBalance[_user] = _newBalance;
    _totalBalance -= _amount;
  }

  function slash() external {
    uint256 _period = getPeriod();
    _periodSlashed[_period] = true;
    _sinkPendingReward(poolAddr);
  }

  function recordReward(uint256 _rewardAmount) external {
    _recordReward(poolAddr, _rewardAmount);
  }

  function settledPools(address[] calldata _addrList) external {
    _onPoolsSettled(_addrList);
  }

  function increaseAccumulatedRps(uint256 _amount) external {
    _recordReward(poolAddr, _amount);
  }

  function getPeriod() public view returns (uint256) {
    return _currentPeriod();
  }

  function claimReward(address _user) external returns (uint256 _amount) {
    _amount = _claimReward(poolAddr, _user);
  }

  function balanceOf(address, address _user) public view override returns (uint256) {
    return _stakingBalance[_user];
  }

  function bulkBalanceOf(address[] calldata _poolAddrs, address[] calldata _userList)
    external
    view
    override
    returns (uint256[] memory)
  {}

  function totalBalance(address) public view virtual override returns (uint256) {
    return _totalBalance;
  }

  function _rewardSinked(address, uint256 _period) internal view override returns (bool) {
    return _periodSlashed[_period];
  }

  function _currentPeriod() internal view override returns (uint256 _period) {
    return _lastUpdatedPeriod;
  }

  function totalBalances(address[] calldata _poolAddr) external view override returns (uint256[] memory) {}
}
