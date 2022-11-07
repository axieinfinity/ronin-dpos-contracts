// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IBaseStaking {
  /// @dev Emitted when the minium number of seconds to undelegate is updated.
  event MinSecsToUndelegateUpdated(uint256 minSecs);
  /// @dev Emitted when the number of seconds that a candidate must wait to be revoked.
  event SecsForRevokingUpdated(uint256 secs);

  struct PoolDetail {
    // Address of the pool
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

  /**
   * @dev Returns the minium number of seconds to undelegate.
   */
  function minSecsToUndelegate() external view returns (uint256);

  /**
   * @dev Returns the number of seconds that a candidate must wait to be revoked.
   */
  function secsForRevoking() external view returns (uint256);

  /**
   * @dev Sets the minium number of seconds to undelegate.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the event `MinSecsToUndelegateUpdated`.
   *
   */
  function setMinSecsToUndelegate(uint256 _minSecs) external;

  /**
   * @dev Sets the number of seconds that a candidate must wait to be revoked.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the event `SecsForRevokingUpdated`.
   *
   */
  function setSecsForRevoking(uint256 _secs) external;
}
