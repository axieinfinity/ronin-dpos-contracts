// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { TPoolId } from "../udvts/Types.sol";
import "../utils/RoleAccess.sol";

interface IProfile {
  struct CandidateProfile {
    /**
     * @dev Primary key of the profile, use for backward querying.
     *
     * {Staking} Contract: index of pool
     * {RoninValidatorSet} Contract: index of almost all data related to a validator
     *
     */
    TPoolId id;
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

  /// @dev Event emitted when a profile with `id` is added.
  event ProfileAdded(TPoolId indexed id);
  /// @dev Event emitted when a address in a profile is changed.
  event ProfileAddressChanged(TPoolId indexed id, RoleAccess indexed addressType);

  /// @dev Error of already existed profile.
  error ErrExistentProfile();

  /// @dev Getter to query full `profile` from `id` address.
  function getId2Profile(TPoolId id) external view returns (CandidateProfile memory profile);

  /// @dev Getter to backward query from `consensus` address to `id` address.
  function getConsensus2Id(address consensus) external view returns (TPoolId id);

  /// @dev Getter to backward batch query from `consensus` address to `id` address.
  function getManyConsensus2Id(address[] memory consensus) external view returns (TPoolId[] memory);

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
