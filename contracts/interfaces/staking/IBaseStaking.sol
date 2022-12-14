// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IBaseStaking {
  struct PoolDetail {
    // Address of the pool i.e. consensus address of the validator
    address addr;
    // Pool admin address
    address admin;
    // Self-staking amount
    uint256 stakingAmount;
    // Total number of RON staking for the pool
    uint256 stakingTotal;
    // Mapping from delegator => delegating amount
    mapping(address => uint256) delegatingAmount;
    // Mapping from delegator => the last timestamp that delegator staked
    mapping(address => uint256) lastDelegatingTimestamp;
  }

  /// @dev Emitted when the minium number of seconds to undelegate is updated.
  event CooldownSecsToUndelegateUpdated(uint256 minSecs);
  /// @dev Emitted when the number of seconds that a candidate must wait to be revoked.
  event WaitingSecsToRevokeUpdated(uint256 secs);

  /**
   * @dev Returns whether the `_poolAdminAddr` is currently active.
   */
  function isPoolAdminActive(address _poolAdminAddr) external view returns (bool);

  /**
   * @dev Returns The cooldown time in seconds to undelegate from the last timestamp (s)he delegated.
   */
  function cooldownSecsToUndelegate() external view returns (uint256);

  /**
   * @dev Returns the number of seconds that a candidate must wait for the renounce request gets affected.
   */
  function waitingSecsToRevoke() external view returns (uint256);

  /**
   * @dev Sets the cooldown time in seconds to undelegate from the last timestamp (s)he delegated.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the event `CooldownSecsToUndelegateUpdated`.
   *
   */
  function setCooldownSecsToUndelegate(uint256 _cooldownSecs) external;

  /**
   * @dev Sets the number of seconds that a candidate must wait to be revoked.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the event `WaitingSecsToRevokeUpdated`.
   *
   */
  function setWaitingSecsToRevoke(uint256 _secs) external;
}
