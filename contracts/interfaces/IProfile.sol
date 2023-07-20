// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../utils/RoleAccess.sol";

interface IProfile {
  struct PublicKey {
    bytes32 firstHalf;
    bytes32 secondHalf;
  }

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
    /// @dev Address to voting proposal.
    address governor;
    /// @dev Public key for fast finality.
    PublicKey pubkey;
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

  /**
   * @notice Add a new profile.
   *
   * @dev Requirements:
   * - The profile must not be existent before.
   * - Only contract admin can call this method.
   */
  function addNewProfile(CandidateProfile memory profile) external;
}
