// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { TConsensus } from "../../udvts/Types.sol";

interface ICandidateManagerCallback {
  /// @dev Emitted when a schedule for updating commission rate is set.
  event CommissionRateUpdateScheduled(address indexed cid, uint256 effectiveTimestamp, uint256 rate);
  /// @dev Error of already requested revoking candidate before.
  error ErrAlreadyRequestedRevokingCandidate();
  /// @dev Error of commission change schedule exists.
  error ErrAlreadyRequestedUpdatingCommissionRate();
  /// @dev Error of trusted org cannot renounce.
  error ErrTrustedOrgCannotRenounce();
  /// @dev Error of invalid effective days onwards.
  error ErrInvalidEffectiveDaysOnwards();

  /**
   * @dev Grants a validator candidate.
   *
   * Requirements:
   * - The method caller is staking contract.
   *
   * Emits the event `CandidateGranted`.
   *
   */
  function execApplyValidatorCandidate(
    address candidateAdmin,
    address cid,
    address payable treasuryAddr,
    uint256 commissionRate
  ) external;

  /**
   * @dev Requests to revoke a validator candidate in next `secsLeft` seconds.
   *
   * Requirements:
   * - The method caller is staking contract.
   *
   * Emits the event `CandidateRevokingTimestampUpdated`.
   *
   */
  function execRequestRenounceCandidate(address cid, uint256 secsLeft) external;

  /**
   * @dev Fallback function of `CandidateStaking-requestUpdateCommissionRate`.
   *
   * Requirements:
   * - The method caller is the staking contract.
   * - The `effectiveTimestamp` must be the beginning of a UTC day, and at least from 7 days onwards
   * - The `rate` must be in range of [0_00; 100_00].
   *
   * Emits the event `CommissionRateUpdateScheduled`.
   *
   */
  function execRequestUpdateCommissionRate(address cid, uint256 effectiveTimestamp, uint256 rate) external;

  /**
   * @dev Fallback function of `Profile-requestChangeAdminAddress`.
   * This updates the shadow storage slot of "shadowedAdmin" for candidate id `id` to `newAdmin`.
   *
   * Requirements:
   * - The caller must be the Profile contract.
   */
  function execChangeAdminAddress(address cid, address newAdmin) external;

  /**
   * @dev Fallback function of `Profile-requestChangeConsensusAddress`.
   * This updates the shadow storage slot of "shadowedConsensus" for candidate id `id` to `newAdmin`.
   *
   * Requirements:
   * - The caller must be the Profile contract.
   */
  function execChangeConsensusAddress(address cid, TConsensus newConsensus) external;

  /**
   * @dev Fallback function of `Profile-requestChangeTreasuryAddress`.
   * This updates the shadow storage slot of "shadowedTreasury" for candidate id `id` to `newAdmin`.
   *
   * Requirements:
   * - The caller must be the Profile contract.
   */
  function execChangeTreasuryAddress(address cid, address payable newTreasury) external;
}
