// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { TPoolId, TConsensus } from "../udvts/Types.sol";
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
    address id;
    /// @dev Consensus address.
    TConsensus consensus;
    /// @dev Pool admin address.
    address admin;
    /// @dev Treasury address.
    address payable treasury;
    /// @dev Address to voting proposal.
    address governor;
    /// @dev Public key for fast finality.
    bytes pubkey;
  }

  /// @dev Event emitted when a profile with `id` is added.
  event ProfileAdded(address indexed id);
  /// @dev Event emitted when a address in a profile is changed.
  event ProfileAddressChanged(address indexed id, RoleAccess indexed addressType);

  /// @dev Error of already existed profile.
  error ErrExistentProfile();
  /// @dev Error of non existed profile.
  error ErrNonExistentProfile();

  /// @dev Getter to query full `profile` from `id` address.
  function getId2Profile(address id) external view returns (CandidateProfile memory profile);

  /// @dev Getter to backward query from `consensus` address to `id` address.
  function getConsensus2Id(TConsensus consensus) external view returns (address id);

  /// @dev Getter to backward batch query from `consensus` address to `id` address.
  function getManyConsensus2Id(TConsensus[] memory consensus) external view returns (address[] memory);

  /**
   * @notice Add a new profile.
   *
   * @dev Requirements:
   * - The profile must not be existent before.
   * - Only contract admin can call this method.
   */
  function addNewProfile(CandidateProfile memory profile) external;

  /**
   * @dev Cross-contract function to add/update new profile of a validator candidate when they
   * applying for candidate role.
   *
   * Requirements:
   * - Only `stakingContract` can call this method.
   */
  function execApplyValidatorCandidate(address admin, address id, address treasury) external;

  /**
   * @dev Updated immediately without waiting time.
   *
   * Emit an {ProfileAddressChanged}.
   */
  function requestChangeAdminAddress(address id, address newAdminAddr) external;

  /**
   * @dev Updated immediately without waiting time. (???)
   *
   * Emit an {ProfileAddressChanged}.
   */
  function requestChangeConsensusAddr(address id, TConsensus newConsensusAddr) external;
}
