// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IProfile {
  struct CandidateProfile {
    /**
     * @dev Primary key of the profile, use for backward querying.
     *
     * {Staking} Contract: index of pool
     * {RoninValidatorSet} Contract: index of almost all data related to a validator
     *
     */
    address id;
    /// @dev Consensus address.
    address consensus;
    /// @dev Pool admin address.
    address admin;
    /// @dev Treasury address.
    address payable treasury;
    /// @dev Address of the bridge operator corresponding to the candidate.
    address bridgeOperator;
    /// @dev Address to voting proposal.
    address governor;
    /// @dev Address to voting bridge operators.
    address bridgeVoter;
  }

  /// @dev Getter to query full `profile` from `id` address.
  function getId2Profile(address id) external view returns (CandidateProfile memory profile);

  /// @dev Getter to backward query from `consensus` address to `id` address.
  function getConsensus2Id(address consensus) external view returns (address id);

  /// @dev Getter to backward batch query from `consensus` address to `id` address.
  function getManyConsensus2Id(address[] memory consensus) external view returns (address[] memory);

  /**
   * @dev Cross-contract function to add/update new profile of a validator candidate when they
   * applying for candidate role.
   *
   * Requirements:
   * - Only `stakingContract` can call this method.
   *
   */
  function execApplyValidatorCandidate(
    address admin,
    address consensus,
    address treasury,
    address bridgeOperator
  ) external;
}
