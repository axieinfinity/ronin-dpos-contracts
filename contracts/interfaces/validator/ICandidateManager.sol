// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ICandidateManager {
  struct ValidatorCandidate {
    // Admin of the candidate
    address admin;
    // Address of the validator that produces block, e.g. block.coinbase. This is so-called validator address.
    address consensusAddr;
    // Address that receives mining reward of the validator
    address payable treasuryAddr;
    // Address of the bridge operator corresponding to the candidate
    address ______deprecatedbridgeOperatorAddr;
    // The percentage of reward that validators can be received, the rest goes to the delegators.
    // Values in range [0; 100_00] stands for 0-100%
    uint256 commissionRate;
    // The timestamp that scheduled to revoke the candidate (no schedule=0)
    uint256 revokingTimestamp;
    // The deadline that the candidate must top up staking amount to keep it larger than or equal to the threshold (no deadline=0)
    uint256 topupDeadline;
  }

  struct CommissionSchedule {
    // The timestamp that the commission schedule gets affected (no schedule=0).
    uint256 effectiveTimestamp;
    // The new commission rate. Value is in range [0; 100_00], stands for 0-100%
    uint256 commissionRate;
  }

  /// @dev Emitted when the maximum number of validator candidates is updated.
  event MaxValidatorCandidateUpdated(uint256 threshold);
  /// @dev Emitted when the min offset to the effective date of commission rate change is updated.
  event MinEffectiveDaysOnwardsUpdated(uint256 numOfDays);
  /// @dev Emitted when the validator candidate is granted.
  event CandidateGranted(address indexed consensusAddr, address indexed treasuryAddr, address indexed admin);
  /// @dev Emitted when the revoking timestamp of a candidate is updated.
  event CandidateRevokingTimestampUpdated(address indexed consensusAddr, uint256 revokingTimestamp);
  /// @dev Emitted when the topup deadline of a candidate is updated.
  event CandidateTopupDeadlineUpdated(address indexed consensusAddr, uint256 topupDeadline);
  /// @dev Emitted when the validator candidate is revoked.
  event CandidatesRevoked(address[] consensusAddrs);

  /// @dev Emitted when a schedule for updating commission rate is set.
  event CommissionRateUpdateScheduled(address indexed consensusAddr, uint256 effectiveTimestamp, uint256 rate);
  /// @dev Emitted when the commission rate of a validator is updated.
  event CommissionRateUpdated(address indexed consensusAddr, uint256 rate);

  /// @dev Error of exceeding maximum number of candidates.
  error ErrExceedsMaxNumberOfCandidate();
  /// @dev Error of querying for already existent candidate.
  error ErrExistentCandidate();
  /// @dev Error of querying for non-existent candidate.
  error ErrNonExistentCandidate();
  /// @dev Error of candidate admin already exists.
  error ErrExistentCandidateAdmin(address _candidateAdminAddr);
  /// @dev Error of treasury already exists.
  error ErrExistentTreasury(address _treasuryAddr);
  /// @dev Error of invalid commission rate.
  error ErrInvalidCommissionRate();
  /// @dev Error of invalid effective days onwards.
  error ErrInvalidEffectiveDaysOnwards();
  /// @dev Error of invalid min effective days onwards.
  error ErrInvalidMinEffectiveDaysOnwards();
  /// @dev Error of already requested revoking candidate before.
  error ErrAlreadyRequestedRevokingCandidate();
  /// @dev Error of commission change schedule exists.
  error ErrAlreadyRequestedUpdatingCommissionRate();
  /// @dev Error of trusted org cannot renounce.
  error ErrTrustedOrgCannotRenounce();

  /**
   * @dev Returns the maximum number of validator candidate.
   */
  function maxValidatorCandidate() external view returns (uint256);

  /**
   * @dev Returns the minimum number of days to the effective date of commission rate change.
   */
  function minEffectiveDaysOnward() external view returns (uint256);

  /**
   * @dev Sets the maximum number of validator candidate.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the `MaxValidatorCandidateUpdated` event.
   *
   */
  function setMaxValidatorCandidate(uint256) external;

  /**
   * @dev Sets the minimum number of days to the effective date of commision rate change.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the `MinEffectiveDaysOnwardsUpdated` event.
   *
   */
  function setMinEffectiveDaysOnwards(uint256 _numOfDays) external;

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
    address _admin,
    address _consensusAddr,
    address payable _treasuryAddr,
    uint256 _commissionRate
  ) external;

  /**
   * @dev Requests to revoke a validator candidate in next `_secsLeft` seconds.
   *
   * Requirements:
   * - The method caller is staking contract.
   *
   * Emits the event `CandidateRevokingTimestampUpdated`.
   *
   */
  function execRequestRenounceCandidate(address, uint256 _secsLeft) external;

  /**
   * @dev Fallback function of `CandidateStaking-requestUpdateCommissionRate`.
   *
   * Requirements:
   * - The method caller is the staking contract.
   * - The `_effectiveTimestamp` must be the beginning of a UTC day, and at least from 7 days onwards
   * - The `_rate` must be in range of [0_00; 100_00].
   *
   * Emits the event `CommissionRateUpdateScheduled`.
   *
   */
  function execRequestUpdateCommissionRate(address _consensusAddr, uint256 _effectiveTimestamp, uint256 _rate) external;

  /**
   * @dev Returns whether the address is a validator (candidate).
   */
  function isValidatorCandidate(address _addr) external view returns (bool);

  /**
   * @dev Returns the validator candidate.
   */
  function getValidatorCandidates() external view returns (address[] memory);

  /**
   * @dev Returns all candidate info.
   */
  function getCandidateInfos() external view returns (ValidatorCandidate[] memory);

  /**
   * @dev Returns the info of a candidate.
   */
  function getCandidateInfo(address _candidate) external view returns (ValidatorCandidate memory);

  /**
   * @dev Returns whether the address is the candidate admin.
   */
  function isCandidateAdmin(address _candidate, address _admin) external view returns (bool);

  /**
   * @dev Returns the schedule of changing commission rate of a candidate address.
   */
  function getCommissionChangeSchedule(address _candidate) external view returns (CommissionSchedule memory);
}
