// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../udvts/Types.sol";
import "../../utils/RoleAccess.sol";
import { ProfileStorage } from "./ProfileStorage.sol";

abstract contract ProfileHandler is ProfileStorage {
  /**
   * @dev Checks each element in the new profile and reverts if there is duplication with any existing profile.
   */
  function _requireNonDuplicatedInRegistry(CandidateProfile memory profile) internal view {
    _requireNonZeroAndNonDuplicated(RoleAccess.CONSENSUS, TConsensus.unwrap(profile.consensus));
    _requireNonZeroAndNonDuplicated(RoleAccess.CANDIDATE_ADMIN, profile.admin);
    _requireNonZeroAndNonDuplicated(RoleAccess.TREASURY, profile.treasury);
    _requireNonDuplicated(RoleAccess.TREASURY, profile.__reservedGovernor);
    _requireNonDuplicatedPubkey(profile.pubkey);
  }

  function _requireNonZeroAndNonDuplicated(RoleAccess addressType, address addr) internal view {
    if (addr == address(0)) revert ErrZeroAddress(addressType);
    _requireNonDuplicated(addressType, addr);
  }

  function _requireNonDuplicated(RoleAccess addressType, address addr) internal view {
    if (_checkNonDuplicatedAddr(addr)) {
      revert ErrDuplicatedInfo(addressType, uint256(uint160(addr)));
    }
  }

  function _checkNonDuplicatedAddr(address addr) internal view returns (bool) {
    return _registry[uint256(uint160(addr))];
  }

  function _requireNonDuplicatedPubkey(bytes memory pubkey) internal view {
    if (_checkNonDuplicatedPubkey(pubkey)) {
      revert ErrDuplicatedPubkey(pubkey);
    }
  }

  function _checkNonDuplicatedPubkey(bytes memory pubkey) internal view returns (bool) {
    return _registry[_hashPubkey(pubkey)];
  }
}
