// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/collections/HasContracts.sol";
import { IProfile } from "../../interfaces/IProfile.sol";

abstract contract ProfileStorage is IProfile, HasContracts {
  /// @dev Mapping from id address => candidate profile.
  mapping(address => CandidateProfile) internal _id2Profile;
  /**
   * @dev Mapping from any address or keccak256(pubkey) => whether it is already registered.
   * This registry can only be toggled to `true` and NOT vice versa. All registered values
   * cannot be reused.
   */
  mapping(uint256 => bool) internal _registry;
  /// @dev Upgradeable gap.
  bytes32[49] __gap;

  /**
   * @dev Add a profile from memory to storage.
   */
  function _addNewProfile(CandidateProfile storage _profile, CandidateProfile memory newProfile) internal {
    _profile.id = newProfile.id;
    _profile.consensus = newProfile.consensus;
    _profile.admin = newProfile.admin;
    _profile.treasury = newProfile.treasury;
    _profile.governor = newProfile.governor;
    _profile.pubkey = newProfile.pubkey;

    _registry[uint256(uint160(newProfile.id))] = true;
    _registry[uint256(uint160(newProfile.consensus))] = true;
    _registry[uint256(uint160(newProfile.admin))] = true;
    _registry[uint256(uint160(address(newProfile.treasury)))] = true;
    _registry[uint256(uint160(newProfile.governor))] = true;
    _registry[_hashPubkey(newProfile.pubkey)] = true;

    emit ProfileAdded(newProfile.id);
  }

  /**
   * @dev Get an existed profile struct from `id`. Revert if the profile does not exists.
   */
  function _getId2ProfileHelper(address id) internal view returns (CandidateProfile storage _profile) {
    _profile = _id2Profile[id];
    if (_profile.id == address(0)) revert ErrNonExistentProfile();
  }

  /**
   * @dev Checks each element in the new profile and reverts if there is duplication with any existing profile.
   */
  function _checkDuplicatedInRegistry(CandidateProfile memory profile) internal view {
    _checkDuplicatedConsensus(profile.consensus);
    _checkDuplicatedAdmin(profile.admin);
    _checkDuplicatedTreasury(profile.treasury);
    _checkDuplicatedGovernor(profile.governor);
    _checkDuplicatedPubkey(profile.pubkey);
  }

  function _checkDuplicatedConsensus(address consensus) internal view {
    if (_registry[uint256(uint160(consensus))]) {
      revert ErrDuplicatedInfo("consensus", uint256(uint160(consensus)));
    }
  }

  function _checkDuplicatedAdmin(address admin) internal view {
    if (_registry[uint256(uint160(admin))]) {
      revert ErrDuplicatedInfo("admin", uint256(uint160(admin)));
    }
  }

  function _checkDuplicatedTreasury(address treasury) internal view {
    if (_registry[uint256(uint160(treasury))]) {
      revert ErrDuplicatedInfo("treasury", uint256(uint160(treasury)));
    }
  }

  function _checkDuplicatedGovernor(address governor) internal view {
    if (_registry[uint256(uint160(governor))]) {
      revert ErrDuplicatedInfo("governor", uint256(uint160(governor)));
    }
  }

  function _checkDuplicatedPubkey(bytes memory pubkey) internal view {
    if (_registry[_hashPubkey(pubkey)]) {
      revert ErrDuplicatedInfo("pubkey", _hashPubkey(pubkey));
    }
  }

  /**
   * @dev Returns hash of a public key.
   */
  function _hashPubkey(bytes memory pubkey) internal pure returns (uint256) {
    return uint256(keccak256(pubkey));
  }
}
