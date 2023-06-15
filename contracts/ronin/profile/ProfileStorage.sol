// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../udvts/Types.sol";
import { IProfile } from "../../interfaces/IProfile.sol";

abstract contract ProfileStorage is IProfile {
  /// @dev Mapping from id address => candidate profile.
  mapping(TPoolId => CandidateProfile) public _id2Profile;
  /// @dev Mapping from consensus address => id address.
  mapping(address => TPoolId) public _consensus2Id;

  function _addNewProfile(CandidateProfile storage _profile, CandidateProfile memory mNewProfile) internal {
    _consensus2Id[mNewProfile.consensus] = mNewProfile.id;

    _profile.id = mNewProfile.id;
    _profile.consensus = mNewProfile.consensus;
    _profile.admin = mNewProfile.admin;
    _profile.treasury = mNewProfile.treasury;
    _profile.bridgeOperator = mNewProfile.bridgeOperator;
    _profile.governor = mNewProfile.governor;
    _profile.bridgeVoter = mNewProfile.bridgeVoter;

    emit ProfileAdded(mNewProfile.id);
  }

  function _getId2ProfileHelper(TPoolId id) internal view returns (CandidateProfile storage _profile) {
    _profile = _id2Profile[id];
    if (TPoolId.unwrap(_profile.id) != address(0)) revert ErrExistentProfile();
  }
}
