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
    address bridgeOperatorAddr;
    // The percentage of reward that validators can be received, the rest goes to the delegators.
    // Values in range [0; 100_00] stands for 0-100%
    uint256 commissionRate;
    // The timestamp that the candidate to be revoked.
    uint256 revokedTimestamp;
    // Extra data
    bytes extraData;
  }

  /// @dev Emitted when the maximum number of validator candidates is updated.
  event MaxValidatorCandidateUpdated(uint256 threshold);
  /// @dev Emitted when the validator candidate is granted.
  event CandidateGranted(
    address indexed consensusAddr,
    address indexed treasuryAddr,
    address indexed admin,
    address bridgeOperator
  );
  /// @dev Emitted when the revoked timestamp of a candidate is updated.
  event CandidateRevokedTimestampUpdated(address indexed consensusAddr, uint256 revokedTimestamp);
  /// @dev Emitted when the validator candidate is revoked.
  event CandidatesRevoked(address[] consensusAddrs);

  /**
   * @dev Returns the maximum number of validator candidate.
   */
  function maxValidatorCandidate() external view returns (uint256);

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
   * @dev Grants a validator candidate.
   *
   * Requirements:
   * - The method caller is staking contract.
   *
   * Emits the event `CandidateGranted`.
   *
   */
  function grantValidatorCandidate(
    address _admin,
    address _consensusAddr,
    address payable _treasuryAddr,
    address _bridgeOperatorAddr,
    uint256 _commissionRate
  ) external;

  /**
   * @dev Requests to revoke a validator candidate in next `_secsLeft` seconds.
   *
   * Requirements:
   * - The method caller is staking contract.
   *
   * Emits the event `CandidateRevokedTimestampUpdated`.
   *
   */
  function requestRevokeCandidate(address, uint256 _secsLeft) external;

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
   * @dev Returns the period index from the current block.
   */
  function currentPeriod() external view returns (uint256);

  /**
   * @dev Returns the block number that the current period starts at.
   */
  function currentPeriodStartAtBlock() external view returns (uint256);

  /**
   * @dev Returns the number of blocks in a epoch.
   */
  function numberOfBlocksInEpoch() external view returns (uint256 _numberOfBlocks);
}
