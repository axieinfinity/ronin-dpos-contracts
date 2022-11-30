// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IRewardPool.sol";

interface ICandidateStaking is IRewardPool {
  /// @dev Emitted when the minimum staking amount for being a validator is updated.
  event MinValidatorStakingAmountUpdated(uint256 threshold);

  /// @dev Emitted when the pool admin staked for themself.
  event Staked(address indexed consensuAddr, uint256 amount);
  /// @dev Emitted when the pool admin unstaked the amount of RON from themself.
  event Unstaked(address indexed consensuAddr, uint256 amount);

  /// @dev Emitted when the validator pool is approved.
  event PoolApproved(address indexed validator, address indexed admin);
  /// @dev Emitted when the validator pool is deprecated.
  event PoolsDeprecated(address[] validator);
  /// @dev Emitted when the staking amount transfer failed.
  event StakingAmountTransferFailed(
    address indexed validator,
    address indexed admin,
    uint256 amount,
    uint256 contractBalance
  );
  /// @dev Emitted when the staking amount deducted failed, e.g. when the validator gets slashed.
  event StakingAmountDeductFailed(
    address indexed validator,
    address indexed recipient,
    uint256 amount,
    uint256 contractBalance
  );

  /**
   * @dev Returns the minimum threshold for being a validator candidate.
   */
  function minValidatorStakingAmount() external view returns (uint256);

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
   * @dev Proposes a candidate to become a validator.
   *
   * Requirements:
   * - The method caller is able to receive RON.
   * - The treasury is able to receive RON.
   * - The amount is larger than or equal to the minimum validator staking amount `minValidatorStakingAmount()`.
   *
   * Emits the event `PoolApproved`.
   *
   * @param _candidateAdmin the candidate admin will be stored in the validator contract, used for calling function that affects
   * to its candidate, e.g. scheduling maintenance.
   *
   */
  function applyValidatorCandidate(
    address _candidateAdmin,
    address _consensusAddr,
    address payable _treasuryAddr,
    address _bridgeOperatorAddr,
    uint256 _commissionRate
  ) external payable;

  /**
   * @dev Deprecates the pool.
   *
   * Requirements:
   * - The method caller is validator contract.
   *
   * Emits the event `PoolsDeprecated` and `Unstaked` events.
   * Emits the event `StakingAmountTransferFailed` if the contract cannot transfer RON back to the pool admin.
   *
   */
  function deprecatePools(address[] calldata _pools) external;

  /**
   * @dev Self-delegates to the validator candidate `_consensusAddr`.
   *
   * Requirements:
   * - The consensus address is a validator candidate.
   * - The method caller is the pool admin.
   * - The `msg.value` is larger than 0.
   *
   * Emits the event `Staked`.
   *
   */
  function stake(address _consensusAddr) external payable;

  /**
   * @dev Unstakes from the validator candidate `_consensusAddr` for `_amount`.
   *
   * Requirements:
   * - The consensus address is a validator candidate.
   * - The method caller is the pool admin.
   *
   * Emits the event `Unstaked`.
   *
   */
  function unstake(address _consensusAddr, uint256 _amount) external;

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
    address _consensusAddr,
    uint256 _effectiveDaysOnwards,
    uint256 _commissionRate
  ) external;

  /**
   * @dev Renounces being a validator candidate and takes back the delegating/staking amount.
   *
   * Requirements:
   * - The consensus address is a validator candidate.
   * - The method caller is the pool admin.
   *
   */
  function requestRenounce(address _consensusAddr) external;
}
