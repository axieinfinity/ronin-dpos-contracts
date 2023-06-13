// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../extensions/consumers/GlobalConfigConsumer.sol";
import "../ronin/staking/RewardCalculation.sol";

contract MockStaking is RewardCalculation, GlobalConfigConsumer {
  /// @dev Mapping from user => staking balance
  mapping(address => uint256) internal _stakingAmount;
  /// @dev Mapping from period number => slashed
  mapping(uint256 => bool) internal _periodSlashed;

  uint256 internal _stakingTotal;

  uint256 public lastUpdatedPeriod;
  uint256 public pendingReward;
  address public poolAddr;

  constructor(address _poolAddr) {
    poolAddr = _poolAddr;
  }

  function firstEverWrapup() external {
    delete pendingReward;
    lastUpdatedPeriod = block.timestamp / PERIOD_DURATION + 1;
  }

  function endPeriod() external {
    address[] memory _addrs = new address[](1);
    uint256[] memory _rewards = new uint256[](1);
    _addrs[0] = poolAddr;
    _rewards[0] = pendingReward;
    this.execRecordRewards(_addrs, _rewards);

    pendingReward = 0;
    lastUpdatedPeriod++;
  }

  function increasePeriod() external {
    lastUpdatedPeriod++;
  }

  function stake(address _user, uint256 _amount) external {
    uint256 _lastStakingAmount = _stakingAmount[_user];
    uint256 _newStakingAmount = _lastStakingAmount + _amount;
    _syncUserReward(poolAddr, _user, _newStakingAmount);
    _stakingAmount[_user] = _newStakingAmount;
    _stakingTotal += _amount;
  }

  function unstake(address _user, uint256 _amount) external {
    uint256 _lastStakingAmount = _stakingAmount[_user];
    uint256 _newStakingAmount = _lastStakingAmount - _amount;
    _syncUserReward(poolAddr, _user, _newStakingAmount);
    _stakingAmount[_user] = _newStakingAmount;
    _stakingTotal -= _amount;
  }

  function increaseReward(uint256 _amount) external {
    pendingReward += _amount;
  }

  function decreaseReward(uint256 _amount) external {
    pendingReward -= _amount;
  }

  function execRecordRewards(address[] calldata _addrList, uint256[] calldata _rewards) external {
    _recordRewards(_addrList, _rewards, _currentPeriod());
  }

  function getPeriod() public view returns (uint256) {
    return _currentPeriod();
  }

  function claimReward(address _user) external returns (uint256 _amount) {
    _amount = _claimReward(poolAddr, _user, getPeriod());
  }

  function getStakingAmount(address, address _user) public view override returns (uint256) {
    return _stakingAmount[_user];
  }

  function getManyStakingAmounts(
    address[] calldata _poolAddrs,
    address[] calldata _userList
  ) external view override returns (uint256[] memory) {}

  function getStakingTotal(address _addr) public view virtual override returns (uint256) {
    return _addr == poolAddr ? _stakingTotal : 0;
  }

  function _currentPeriod() internal view override returns (uint256 _period) {
    return lastUpdatedPeriod;
  }

  function getManyStakingTotals(address[] calldata _poolAddr) external view override returns (uint256[] memory) {}
}
