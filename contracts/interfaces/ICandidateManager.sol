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
    // Extra data
    bytes extraData;
  }

  /// @dev Emitted when the maximum number of validator candidates is updated.
  event MaxValidatorCandidateUpdated(uint256 threshold);
  /// @dev Emitted when the validator candidate is added.
  event ValidatorCandidateAdded(
    address indexed consensusAddr,
    address indexed treasuryAddr,
    uint256 indexed candidateIdx
  );
  /// @dev Emitted when the validator candidate is removed.
  event ValidatorCandidateRemoved(address indexed consensusAddr);

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
   * Emits the event `ValidatorCandidateAdded`.
   *
   */
  function addValidatorCandidate(
    address _admin,
    address _consensusAddr,
    address payable _treasuryAddr,
    uint256 _commissionRate
  ) external;

  /**
   * @dev Syncs the validator candidate list (removes the ones who have insufficient minimum candidate balance).
   * Returns the total balance list of the new candidate list.
   *
   * Emits the event `ValidatorCandidateRemoved` when a candidate is removed.
   *
   */
  function syncCandidates() external returns (uint256[] memory _balances);

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
}
