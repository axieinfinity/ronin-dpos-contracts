// SPDX-License-Identifier: MIT

import "../../interfaces/IProfile.sol";
import { ContractType } from "../../utils/ContractType.sol";
import "./ProfileHandler.sol";

pragma solidity ^0.8.9;

abstract contract ProfileXComponents is IProfile, ProfileHandler {
  /**
   * @inheritdoc IProfile
   */
  function execApplyValidatorCandidate(
    address admin,
    address id,
    address treasury
  ) external override onlyContract(ContractType.STAKING) {
    // Check existent profile
    CandidateProfile storage _profile = _id2Profile[id];
    if (_profile.id != address(0)) revert ErrExistentProfile();

    // Validate the info and add the profile
    CandidateProfile memory profile = CandidateProfile({
      id: id,
      consensus: TConsensus.wrap(id),
      admin: admin,
      treasury: payable(treasury),
      governor: address(0),
      pubkey: "" // TODO: Handle add pubkey
    });
    _checkDuplicatedInRegistry(profile);
    _addNewProfile(_profile, profile);
  }
}
