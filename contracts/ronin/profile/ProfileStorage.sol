// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/collections/HasContracts.sol";
import { IProfile } from "../../interfaces/IProfile.sol";

abstract contract ProfileStorage is IProfile, HasContracts {
  /// @dev Mapping from id address => candidate profile.
  mapping(address => CandidateProfile) internal _id2Profile;
  /// @dev Mapping from any address or keccak256(pubkey) => whether it is already registered.
  mapping(uint256 => bool) internal _registry;
  /// @dev Upgradeable gap.
  bytes32[50] __gap;

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
   * @dev Get an existed profile struct from id. Revert if the profile does not exists.
   */
  function _getId2ProfileHelper(address id) internal view returns (CandidateProfile storage _profile) {
    _profile = _id2Profile[id];
    if (_profile.id == address(0)) revert ErrNonExistentProfile();
  }

  /**
   * @dev Checks each element in the candidate profile and reverts if there is duplication with any existing profile.
   */
  function _checkDuplicatedInRegistry(CandidateProfile memory profile) internal {
    if (_registry[uint256(uint160(profile.consensus))]) {
      revert ErrDuplicatedInfo("consensus", uint256(uint160(profile.consensus)));
    }
    if (_registry[uint256(uint160(profile.admin))]) {
      revert ErrDuplicatedInfo("admin", uint256(uint160(profile.admin)));
    }
    if (_registry[uint256(uint160(address(profile.treasury)))]) {
      revert ErrDuplicatedInfo("treasury", uint256(uint160(address(profile.treasury))));
    }
    if (_registry[uint256(uint160(profile.governor))]) {
      revert ErrDuplicatedInfo("governor", uint256(uint160(profile.governor)));
    }
    if (_registry[_hashPubkey(profile.pubkey)]) {
      revert ErrDuplicatedInfo("pubkey", _hashPubkey(profile.pubkey));
    }
  }

  /**
   * @dev Returns hash of a public key.
   */
  function _hashPubkey(bytes memory pubkey) internal pure returns (uint256) {
    return uint256(keccak256(pubkey));
  }
}
