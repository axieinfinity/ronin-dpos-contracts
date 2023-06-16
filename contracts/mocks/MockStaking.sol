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
    address[] memory _consensusAddrs = new address[](1);
    uint256[] memory _rewards = new uint256[](1);
    _consensusAddrs[0] = poolAddr;
    _rewards[0] = pendingReward;
    this.execRecordRewards(_consensusAddrs, _rewards);

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

  function execRecordRewards(address[] calldata poolIds, uint256[] calldata rewards) external {
    _recordRewards(poolIds, rewards, _currentPeriod());
  }

  function getPeriod() public view returns (uint256) {
    return _currentPeriod();
  }

  function claimReward(address _user) external returns (uint256 _amount) {
    _amount = _claimReward(poolAddr, _user, getPeriod());
  }

  function getStakingAmount(TConsensus, address _user) public view override returns (uint256) {
    return _getStakingAmount(address(0), _user);
  }

  function getManyStakingAmounts(
    TConsensus[] calldata consensusAddrs,
    address[] calldata userList
  ) external view override returns (uint256[] memory) {}

  function getManyStakingAmountsById(
    address[] calldata poolIds,
    address[] calldata userList
  ) external view override returns (uint256[] memory) {}

  function _getStakingAmount(address, address _user) internal view override returns (uint256) {
    return _stakingAmount[_user];
  }

  function getStakingTotal(TConsensus addr) external view virtual override returns (uint256) {
    return _getStakingTotal(TConsensus.unwrap(addr));
  }

  function _getStakingTotal(address poolId) internal view virtual override returns (uint256) {
    return poolId == poolAddr ? _stakingTotal : 0;
  }

  function _currentPeriod() internal view override returns (uint256 _period) {
    return lastUpdatedPeriod;
  }

  function getManyStakingTotals(TConsensus[] calldata _poolAddr) external view override returns (uint256[] memory) {}

  function getManyStakingTotalsById(
    address[] calldata poolIds
  ) external view returns (uint256[] memory stakingAmounts_) {}
}
