// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

// import "hardhat/console.sol";

abstract contract CoreStaking {
  struct PendingRewardFields {
    // Recorded reward amount.
    uint256 debited;
    // The amount rewards that user have already earned.
    uint256 credited;
    // Last block number that the info updated.
    uint256 lastSyncBlock;
  }

  struct SettledRewardFields {
    // The balance at the commit time.
    uint256 balance;
    // Recorded reward amount.
    uint256 debited;
    // Accumulated of the amount rewards per share (one unit staking).
    uint256 accumulatedRps;
  }

  struct PendingPool {
    // Last block number that the info updated.
    uint256 lastSyncBlock;
    // Accumulated of the amount rewards per share (one unit staking).
    uint256 accumulatedRps;
  }

  struct SettledPool {
    // Last block number that the info updated.
    uint256 lastSyncBlock;
    // Accumulated of the amount rewards per share (one unit staking).
    uint256 accumulatedRps;
  }

  /// @dev Mapping from the user address => settled reward info of the user
  mapping(address => SettledRewardFields) internal _sUserReward;
  /// @dev Mapping from the user address => pending reward info of the user
  mapping(address => PendingRewardFields) internal _pUserReward;

  /**
   * @dev Syncs the user reward.
   *
   * Emits the `` event and the `` event.
   *
   * @notice The method should be called whenever the user's balance changes.
   *
   * TODO: add test to stake/unstake many times in block.
   * TODO: add events.
   *
   */
  function _syncUserReward(address _user, uint256 _newBalance) internal {
    PendingRewardFields storage _reward = _getPendingRewardFields(_user);
    SettledPool memory _sPool = _getSettledPool();

    // Syncs the reward once the last sync is settled.
    if (_reward.lastSyncBlock <= _sPool.lastSyncBlock) {
      SettledRewardFields storage _sReward = _getSettledRewardFields(_user);
      uint256 _claimableReward = getClaimableReward(_user);
      // console.log("Synced for", _user, _claimableReward, _sPool.accumulatedRps);
      _sReward.balance = balanceOf(_user);
      _sReward.debited = _claimableReward;
      _sReward.accumulatedRps = _sPool.accumulatedRps;
    }

    PendingPool memory _pool = _getPendingPool();
    _reward.debited = getTotalReward(_user);
    _reward.credited = (_newBalance * _pool.accumulatedRps) / 1e18;
    _reward.lastSyncBlock = block.number;
  }

  /**
   * @dev Returns the total reward.
   */
  function getTotalReward(address _user) public view returns (uint256) {
    PendingRewardFields memory _reward = _getPendingRewardFields(_user);
    PendingPool memory _pool = _getPendingPool();

    uint256 _balance = balanceOf(_user);
    if (_slashed(_pool, _blockNumberToEpoch(_reward.lastSyncBlock))) {
      SettledRewardFields memory _sReward = _getSettledRewardFields(_user);
      uint256 _credited = (_sReward.accumulatedRps * _balance) / 1e18;
      return (_balance * _pool.accumulatedRps) / 1e18 + _sReward.debited - _credited;
    }

    // console.log("_getUserReward:\t", _balance, _pool.accumulatedRps, _reward.debited);
    // console.log("_getUserReward:\t", _reward.credited);
    return (_balance * _pool.accumulatedRps) / 1e18 + _reward.debited - _reward.credited;
  }

  function getClaimableReward(address _user) public view returns (uint256) {
    PendingRewardFields memory _reward = _getPendingRewardFields(_user);
    SettledRewardFields memory _sReward = _getSettledRewardFields(_user);
    SettledPool memory _sPool = _getSettledPool();

    // console.log("-> getClaimableReward", _user, _reward.lastSyncBlock, _sPool.lastSyncBlock);
    if (_reward.lastSyncBlock <= _sPool.lastSyncBlock) {
      // console.log("\t-> sync");
      uint256 _currentBalance = balanceOf(_user);
      _sReward.debited = (_currentBalance * _sPool.accumulatedRps) / 1e18 + _reward.debited - _reward.credited;
      _sReward.balance = _currentBalance;
      _sReward.accumulatedRps = _sPool.accumulatedRps;
    }

    uint256 _balance = _sReward.balance;
    uint256 _credited = (_balance * _sReward.accumulatedRps) / 1e18;
    // console.log("\t", _balance, _sReward.accumulatedRps, _sPool.accumulatedRps);
    // console.log("\t", _sReward.debited);
    return (_balance * _sPool.accumulatedRps) / 1e18 + _sReward.debited - _credited;
  }

  /**
   * @dev Returns the pending reward.
   */
  function getPendingReward(address _user) external view returns (uint256 _amount) {
    _amount = getTotalReward(_user) - getClaimableReward(_user);
  }

  /**
   * @dev Claims the settled reward for a specific user.
   */
  function _claimReward(address _user) public returns (uint256 _amount) {
    // uint256 _balance = balanceOf(_user);
    _amount = getClaimableReward(_user);
    SettledPool memory _sPool = _getSettledPool();
    // PendingPool memory _pool = _getStakingPool();
    // console.log("User", _user, "claimed", _amount);

    PendingRewardFields storage _reward = _getPendingRewardFields(_user);
    // console.log("claimReward: \t => (+)=", _reward.debited, _reward.debited);
    // console.log("claimReward: \t => (-)=", _reward.credited, _reward.credited + _amount);
    // _reward.debited = 0;
    _reward.credited += _amount;
    _reward.lastSyncBlock = block.number;
    // console.log("claimReward: \t", _balance, _sPool.accumulatedRps);

    SettledRewardFields storage _sReward = _getSettledRewardFields(_user);
    _sReward.debited = 0;
    _sReward.accumulatedRps = _sPool.accumulatedRps;
  }

  /**
   * @dev Returns the pending pool.
   */
  function _getPendingPool() internal view virtual returns (PendingPool memory) {}

  /**
   * @dev Returns settled pool.
   */
  function _getSettledPool() internal view virtual returns (SettledPool memory) {}

  /**
   * @dev Returns the pending reward info of a specific user.
   */
  function _getPendingRewardFields(address _user) internal view virtual returns (PendingRewardFields storage) {
    return _pUserReward[_user];
  }

  /**
   * @dev Returns the settled reward info of a specific user.
   */
  function _getSettledRewardFields(address _user) internal view virtual returns (SettledRewardFields storage) {
    return _sUserReward[_user];
  }

  /**
   * @dev Returns whether the pool is slashed in the epoch `_epoch`.
   */
  function _slashed(PendingPool memory, uint256 _epoch) internal view virtual returns (bool);

  /**
   * @dev Returns the epoch from the block number.
   */
  function _blockNumberToEpoch(uint256) internal view virtual returns (uint256);

  /**
   * @dev Returns the staking amount of the user.
   */
  function balanceOf(address) public view virtual returns (uint256);
}
