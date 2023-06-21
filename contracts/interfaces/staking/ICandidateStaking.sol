// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IRewardPool.sol";

interface ICandidateStaking is IRewardPool {
  /// @dev Emitted when the minimum staking amount for being a validator is updated.
  event MinValidatorStakingAmountUpdated(uint256 threshold);
  /// @dev Emitted when the commission rate range is updated.
  event CommissionRateRangeUpdated(uint256 minRate, uint256 maxRate);

  /// @dev Emitted when the pool admin staked for themself.
  event Staked(address indexed poolId, uint256 amount);
  /// @dev Emitted when the pool admin unstaked the amount of RON from themself.
  event Unstaked(address indexed poolId, uint256 amount);

  /// @dev Emitted when the validator pool is approved.
  event PoolApproved(address indexed validator, address indexed admin);
  /// @dev Emitted when the validator pool is deprecated.
  event PoolsDeprecated(address[] validator);
  /// @dev Emitted when the staking amount transfer failed.
  event StakingAmountTransferFailed(
    address indexed poolId,
    address indexed admin,
    uint256 amount,
    uint256 contractBalance
  );
  /// @dev Emitted when the staking amount deducted failed, e.g. when the validator gets slashed.
  event StakingAmountDeductFailed(
    address indexed poolId,
    address indexed recipient,
    uint256 amount,
    uint256 contractBalance
  );

  /// @dev Error of cannot transfer RON to specified target.
  error ErrCannotInitTransferRON(address addr, string extraInfo);
  /// @dev Error of three interaction addresses must be of the same in applying for validator candidate.
  error ErrThreeInteractionAddrsNotEqual();
  /// @dev Error of unstaking zero amount.
  error ErrUnstakeZeroAmount();
  /// @dev Error of invalid staking amount left after deducted.
  error ErrStakingAmountLeft();
  /// @dev Error of insufficient staking amount for unstaking.
  error ErrInsufficientStakingAmount();
  /// @dev Error of unstaking too early.
  error ErrUnstakeTooEarly();
  /// @dev Error of setting commission rate exceeds max allowed.
  error ErrInvalidCommissionRate();

  /**
   * @dev Returns the minimum threshold for being a validator candidate.
   */
  function minValidatorStakingAmount() external view returns (uint256);

  /**
   * @dev Returns the commission rate range that the candidate can set.
   */
  function getCommissionRateRange() external view returns (uint256 minRange, uint256 maxRange);

  /**
   * @dev Sets the minimum threshold for being a validator candidate.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the `MinValidatorStakingAmountUpdated` event.
   *
   */
  function setMinValidatorStakingAmount(uint256) external;

  /**
   * @dev Sets the commission rate range that a candidate can set.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the `CommissionRateRangeUpdated` event.
   *
   */
  function setCommissionRateRange(uint256 minRate, uint256 maxRate) external;

  /**
   * @dev Proposes a candidate to become a validator.
   *
   * Requirements:
   * - The method caller is able to receive RON.
   * - The treasury is able to receive RON.
   * - The amount is larger than or equal to the minimum validator staking amount `minValidatorStakingAmount()`.
   *
   * Emits the event `PoolApproved`.
   *
   * @param candidateAdmin the candidate admin will be stored in the validator contract, used for calling function that affects
   * to its candidate, e.g. scheduling maintenance.
   *
   */
  function applyValidatorCandidate(
    address candidateAdmin,
    TConsensus consensusAddr,
    address payable treasuryAddr,
    address bridgeOperatorAddr,
    uint256 commissionRate
  ) external payable;

  /**
   * @dev Deprecates the pool.
   * - Deduct self-staking amount of the pool admin to zero.
   * - Transfer the deducted amount to the pool admin.
   * - Deactivate the pool admin address in the mapping of active pool admins
   *
   * Requirements:
   * - The method caller is validator contract.
   *
   * Emits the event `PoolsDeprecated` and `Unstaked` events.
   * Emits the event `StakingAmountTransferFailed` if the contract cannot transfer RON back to the pool admin.
   *
   */
  function execDeprecatePools(address[] calldata pools, uint256 period) external;

  /**
   * @dev Self-delegates to the validator candidate `consensusAddr`.
   *
   * Requirements:
   * - The consensus address is a validator candidate.
   * - The method caller is the pool admin.
   * - The `msg.value` is larger than 0.
   *
   * Emits the event `Staked`.
   *
   */
  function stake(TConsensus consensusAddr) external payable;

  /**
   * @dev Unstakes from the validator candidate `consensusAddr` for `amount`.
   *
   * Requirements:
   * - The consensus address is a validator candidate.
   * - The method caller is the pool admin.
   *
   * Emits the event `Unstaked`.
   *
   */
  function unstake(TConsensus consensusAddr, uint256 amount) external;

  /**
   * @dev Pool admin requests update validator commission rate. The request will be forwarded to the candidate manager
   * contract, and the value is getting updated in {ICandidateManager-execRequestUpdateCommissionRate}.
   *
   * Requirements:
   * - The consensus address is a validator candidate.
   * - The method caller is the pool admin.
   * - The `_effectiveDaysOnwards` must be equal to or larger than the {CandidateManager-_minEffectiveDaysOnwards}.
   * - The `_rate` must be in range of [0_00; 100_00].
   *
   * Emits the event `CommissionRateUpdated`.
   *
   */
  function requestUpdateCommissionRate(
    TConsensus consensusAddr,
    uint256 effectiveDaysOnwards,
    uint256 commissionRate
  ) external;

  /**
   * @dev Renounces being a validator candidate and takes back the delegating/staking amount.
   *
   * Requirements:
   * - The consensus address is a validator candidate.
   * - The method caller is the pool admin.
   *
   */
  function requestRenounce(TConsensus consensusAddr) external;

  /**
   * @dev Renounces being a validator candidate and takes back the delegating/staking amount.
   *
   * Requirements:
   * - The consensus address is a validator candidate.
   * - The method caller is the pool admin.
   *
   */
  function requestEmergencyExit(TConsensus consensusAddr) external;
}
