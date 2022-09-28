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
    // The percentile of reward that validators can be received, the rest goes to the delegators.
    // Values in range [0; 100_00] stands for 0-100%
    uint256 commissionRate;
    // The block that the candidate to be removed.
    uint256 removedAtBlock;
    // Extra data
    bytes extraData;
  }

  /// @dev Emitted when the maximum number of validator candidates is updated.
  event MaxValidatorCandidateUpdated(uint256 threshold);
  /// @dev Emitted when the validator candidate is added.
  event CandidateAdded(address indexed consensusAddr, address indexed treasuryAddr, address indexed admin);
  /// @dev Emitted when the validator candidate is requested to remove at a specific block.
  event CandidateRemovedAtBlock(address indexed consensusAddr, uint256 removedAtBlock);
  /// @dev Emitted when the validator candidate is removed.
  event CandidatesRemoved(address[] consensusAddrs);

  /**
   * @dev Returns the maximum number of validator candidate.
   */
  function maxValidatorCandidate() external view returns (uint256);

  /**
   * @dev Sets the maximum number of validator candidate.
   *
   * Requirements:
   * - The method caller is governance admin.
   *
   * Emits the `MaxValidatorCandidateUpdated` event.
   *
   */
  function setMaxValidatorCandidate(uint256) external;

  /**
   * @dev Adds a validator candidate.
   *
   * Requirements:
   * - The method caller is staking contract.
   *
   * Emits the event `CandidateAdded`.
   *
   */
  function addValidatorCandidate(
    address _admin,
    address _consensusAddr,
    address payable _treasuryAddr,
    uint256 _commissionRate
  ) external;

  /**
   * @dev Requests to remove a validator candidate.
   *
   * Requirements:
   * - The method caller is staking contract.
   *
   * Emits the event `CandidateRemovedAtBlock`.
   *
   */
  function requestRemoveCandidate(address) external;

  /**
   * @dev Returns whether the address is a validator (candidate).
   */
  function isValidatorCandidate(address _addr) external view returns (bool);

  /**
   * @dev Returns the validator candidate.
   */
  function getValidatorCandidates() external view returns (address[] memory);

  /**
   * @dev Returns candidates info.
   */
  function getCandidateInfos() external view returns (ValidatorCandidate[] memory);

  /**
   * @dev Returns whether the address is the candidate admin.
   */
  function isCandidateAdmin(address _candidate, address _admin) external view returns (bool);

  /**
   * @dev Returns the number of epochs in a period.
   */
  function numberOfEpochsInPeriod() external view returns (uint256 _numberOfEpochs);

  /**
   * @dev Returns the number of blocks in a epoch.
   */
  function numberOfBlocksInEpoch() external view returns (uint256 _numberOfBlocks);
}
