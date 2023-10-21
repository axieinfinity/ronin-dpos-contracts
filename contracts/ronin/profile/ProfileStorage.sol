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

    _setConsensus(_profile, newProfile.consensus);
    _setAdmin(_profile, newProfile.admin);
    _setTreasury(_profile, newProfile.treasury);
    _setGovernor(_profile, newProfile.governor);
    _setPubkey(_profile, newProfile.pubkey);

    emit ProfileAdded(newProfile.id);
  }

  function _setConsensus(CandidateProfile storage _profile, address consensus) internal {
    _profile.consensus = consensus;
    _registry[uint256(uint160(consensus))] = true;
  }

  function _setAdmin(CandidateProfile storage _profile, address admin) internal {
    _profile.admin = admin;
    _registry[uint256(uint160(admin))] = true;
  }

  function _setTreasury(CandidateProfile storage _profile, address payable treasury) internal {
    _profile.treasury = treasury;
    _registry[uint256(uint160(address(treasury)))] = true;
  }

  /**
   * @dev Allow to registry a profile without governor address since not all validators are governing validators.
   */
  function _setGovernor(CandidateProfile storage _profile, address governor) internal {
    _profile.governor = governor;
    if (governor != address(0)) {
      _registry[uint256(uint160(governor))] = true;
    }
  }

  function _setPubkey(CandidateProfile storage _profile, bytes memory pubkey) internal {
    _profile.pubkey = pubkey;
    _registry[_hashPubkey(pubkey)] = true;
  }

  /**
   * @dev Get an existed profile struct from `id`. Revert if the profile does not exists.
   */
  function _getId2ProfileHelper(address id) internal view returns (CandidateProfile storage _profile) {
    _profile = _id2Profile[id];
    if (_profile.id == address(0)) revert ErrNonExistentProfile();
  }

  /**
   * @dev Returns hash of a public key.
   */
  function _hashPubkey(bytes memory pubkey) internal pure returns (uint256) {
    return uint256(keccak256(pubkey));
  }
}
