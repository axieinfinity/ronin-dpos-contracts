// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IRewardPool.sol";

interface IDelegatorStaking is IRewardPool {
  /// @dev Emitted when the delegator staked for a validator candidate.
  event Delegated(address indexed delegator, TPoolId indexed poolId, uint256 amount);
  /// @dev Emitted when the delegator unstaked from a validator candidate.
  event Undelegated(address indexed delegator, TPoolId indexed consensusAddr, uint256 amount);

  /// @dev Error of undelegating zero amount.
  error ErrUndelegateZeroAmount();
  /// @dev Error of undelegating insufficient amount.
  error ErrInsufficientDelegatingAmount();
  /// @dev Error of undelegating too early.
  error ErrUndelegateTooEarly();

  /**
   * @dev Stakes for a validator candidate `_consensusAddr`.
   *
   * Requirements:
   * - The consensus address is a validator candidate.
   * - The method caller is not the pool admin.
   *
   * Emits the `Delegated` event.
   *
   */
  function delegate(address consensusAddr) external payable;

  /**
   * @dev Unstakes from a validator candidate `_consensusAddr` for `_amount`.
   *
   * Requirements:
   * - The method caller is not the pool admin.
   *
   * Emits the `Undelegated` event.
   *
   */
  function undelegate(address consensusAddr, uint256 amount) external;

  /**
   * @dev Bulk unstakes from a list of candidates.
   *
   * Requirements:
   * - The method caller is not the pool admin.
   *
   * Emits the events `Undelegated`.
   *
   */
  function bulkUndelegate(address[] calldata consensusAddrs, uint256[] calldata amounts) external;

  /**
   * @dev Unstakes an amount of RON from the `_consensusAddrSrc` and stake for `_consensusAddrDst`.
   *
   * Requirements:
   * - The method caller is not the pool admin.
   * - The consensus address `_consensusAddrDst` is a validator candidate.
   *
   * Emits the `Undelegated` event and the `Delegated` event.
   *
   */
  function redelegate(address consensusAddrSrc, address consensusAddrDst, uint256 amount) external;

  /**
   * @dev Returns the claimable reward of the user `_user`.
   */
  function getRewards(address user, address[] calldata poolAddrList) external view returns (uint256[] memory _rewards);

  /**
   * @dev Claims the reward of method caller.
   *
   * Emits the `RewardClaimed` event.
   *
   */
  function claimRewards(address[] calldata consensusAddrList) external returns (uint256 amount);

  /**
   * @dev Claims the rewards and delegates them to the consensus address.
   *
   * Requirements:
   * - The method caller is not the pool admin.
   * - The consensus address `_consensusAddrDst` is a validator candidate.
   *
   * Emits the `RewardClaimed` event and the `Delegated` event.
   *
   */
  function delegateRewards(
    address[] calldata consensusAddrList,
    address consensusAddrDst
  ) external returns (uint256 amount);
}
