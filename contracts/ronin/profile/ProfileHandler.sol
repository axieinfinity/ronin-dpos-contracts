// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../utils/RoleAccess.sol";
import { ProfileStorage } from "./ProfileStorage.sol";

abstract contract ProfileHandler is ProfileStorage {
  /**
   * @dev Checks each element in the new profile and reverts if there is duplication with any existing profile.
   */
  function _checkDuplicatedInRegistry(CandidateProfile memory profile) internal view {
    _checkNonZeroAndNonDuplicated(RoleAccess.CONSENSUS, profile.consensus);
    _checkNonZeroAndNonDuplicated(RoleAccess.CANDIDATE_ADMIN, profile.admin);
    _checkNonZeroAndNonDuplicated(RoleAccess.TREASURY, profile.treasury);
    _checkNonDuplicated(RoleAccess.TREASURY, profile.governor);
    _checkNonDuplicatedPubkey(profile.pubkey);
  }

  function _checkNonZeroAndNonDuplicated(RoleAccess addressType, address addr) internal view {
    if (addr == address(0)) revert ErrZeroAddress(addressType);
    _checkNonDuplicated(addressType, addr);
  }

  function _checkNonDuplicated(RoleAccess addressType, address addr) internal view {
    if (_registry[uint256(uint160(addr))]) {
      revert ErrDuplicatedInfo(addressType, uint256(uint160(addr)));
    }
  }

  function _checkNonDuplicatedPubkey(bytes memory pubkey) internal view {
    if (_registry[_hashPubkey(pubkey)]) {
      revert ErrDuplicatedPubkey(pubkey);
    }
  }
}
