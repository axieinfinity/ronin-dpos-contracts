// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { TPoolId, TConsensus } from "../../udvts/Types.sol";

interface IBaseStaking {
  struct PoolDetail {
    // [Non-volatile] Address of the pool, permanently set to the first consensus address of the candidate.
    address pid;
    // Pool admin address
    address __shadowedPoolAdmin;
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

  /// @dev Error of cannot transfer RON.
  error ErrCannotTransferRON();
  /// @dev Error of receiving zero message value.
  error ErrZeroValue();
  /// @dev Error of pool admin is not allowed to call.
  error ErrPoolAdminForbidden();
  /// @dev Error of no one is allowed to call but the pool's admin.
  error ErrOnlyPoolAdminAllowed();
  /// @dev Error of admin of any active pool cannot delegate.
  error ErrAdminOfAnyActivePoolForbidden(address admin);
  /// @dev Error of querying inactive pool.
  error ErrInactivePool(TConsensus consensusAddr, address poolAddr);
  /// @dev Error of length of input arrays are not of the same.
  error ErrInvalidArrays();

  /**
   * @dev Returns whether the `admin` is currently active.
   */
  function isAdminOfActivePool(address admin) external view returns (bool);

  /**
   * @dev Returns the consensus address corresponding to the pool admin.
   */
  function getPoolAddressOf(address admin) external view returns (address);

  /**
   * @dev Returns the staking pool details.
   */
  function getPoolDetail(
    TConsensus consensusAddr
  ) external view returns (address admin, uint256 stakingAmount, uint256 stakingTotal);

  function getPoolDetailById(
    address poolId
  ) external view returns (address admin, uint256 stakingAmount, uint256 stakingTotal);

  /**
   * @dev Returns the self-staking amounts of the pools.
   */
  function getManySelfStakings(TConsensus[] calldata consensusAddrs) external view returns (uint256[] memory);

  /**
   * @dev Returns the self-staking amounts of the pools.
   */
  function getManySelfStakingsById(address[] calldata poolIds) external view returns (uint256[] memory);

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
  function setCooldownSecsToUndelegate(uint256 cooldownSecs) external;

  /**
   * @dev Sets the number of seconds that a candidate must wait to be revoked.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the event `WaitingSecsToRevokeUpdated`.
   *
   */
  function setWaitingSecsToRevoke(uint256 secs) external;
}
