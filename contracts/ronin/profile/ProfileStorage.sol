// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../udvts/Types.sol";
import "../../extensions/collections/HasContracts.sol";
import { IProfile } from "../../interfaces/IProfile.sol";

abstract contract ProfileStorage is IProfile, HasContracts {
  /// @dev Mapping from id address => candidate profile.
  mapping(address => CandidateProfile) internal _id2Profile;
  /// @dev Mapping from consensus address => id address.
  mapping(TConsensus => address) internal _consensus2Id;
  /// @dev Upgradeable gap.
  bytes32[50] __gap;

  /**
   * @dev Add a profile from memory to storage.
   */
  function _addNewProfile(CandidateProfile storage _profile, CandidateProfile memory newProfile) internal {
    _consensus2Id[newProfile.consensus] = newProfile.id;

    _profile.id = newProfile.id;
    _profile.consensus = newProfile.consensus;
    _profile.admin = newProfile.admin;
    _profile.treasury = newProfile.treasury;
    _profile.governor = newProfile.governor;
    _profile.pubkey = newProfile.pubkey;

    emit ProfileAdded(newProfile.id);
  }

  /**
   * @dev Get an existed profile struct from id. Revert if the profile does not exists.
   */
  function _getId2ProfileHelper(address id) internal view returns (CandidateProfile storage _profile) {
    _profile = _id2Profile[id];
    if (_profile.id == address(0)) revert ErrNonExistentProfile();
  }
}
