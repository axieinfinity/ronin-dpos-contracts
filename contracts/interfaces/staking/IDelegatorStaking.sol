// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IRewardPool.sol";

interface IDelegatorStaking is IRewardPool {
  /// @dev Emitted when the delegator staked for a validator candidate.
  event Delegated(address indexed delegator, address indexed consensuAddr, uint256 amount);
  /// @dev Emitted when the delegator unstaked from a validator candidate.
  event Undelegated(address indexed delegator, address indexed consensuAddr, uint256 amount);

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
  function delegate(address _consensusAddr) external payable;

  /**
   * @dev Unstakes from a validator candidate `_consensusAddr` for `_amount`.
   *
   * Requirements:
   * - The method caller is not the pool admin.
   *
   * Emits the `Undelegated` event.
   *
   */
  function undelegate(address _consensusAddr, uint256 _amount) external;

  /**
   * @dev Bulk unstakes from a list of candidates.
   *
   * Requirements:
   * - The method caller is not the pool admin.
   *
   * Emits the events `Undelegated`.
   *
   */
  function bulkUndelegate(address[] calldata _consensusAddrs, uint256[] calldata _amounts) external;

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
  function redelegate(address _consensusAddrSrc, address _consensusAddrDst, uint256 _amount) external;

  /**
   * @dev Returns the claimable reward of the user `_user`.
   */
  function getRewards(
    address _user,
    address[] calldata _poolAddrList
  ) external view returns (uint256[] memory _rewards);

  /**
   * @dev Claims the reward of method caller.
   *
   * Emits the `RewardClaimed` event.
   *
   */
  function claimRewards(address[] calldata _consensusAddrList) external returns (uint256 _amount);

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
    address[] calldata _consensusAddrList,
    address _consensusAddrDst
  ) external returns (uint256 _amount);
}
