// SPDX-License-Identifier: MIT

import "../../extensions/collections/HasContracts.sol";
import "../../interfaces/IProfile.sol";
import { ContractType } from "../../utils/ContractType.sol";
import "./ProfileStorage.sol";

pragma solidity ^0.8.9;

abstract contract ProfileXComponents is IProfile, HasContracts, ProfileStorage {
  /**
   * @inheritdoc IProfile
   */
  function execApplyValidatorCandidate(
    address admin,
    address id,
    address treasury,
    address bridgeOperator
  ) external override onlyContract(ContractType.STAKING) {
    // TODO: handle previous added consensus
    CandidateProfile storage _profile = _id2Profile[id];

    CandidateProfile memory mProfile = CandidateProfile({
      id: id,
      consensus: TConsensus.wrap(id),
      admin: admin,
      treasury: payable(treasury),
      bridgeOperator: bridgeOperator,
      governor: address(0),
      bridgeVoter: address(0)
    });

    _addNewProfile(_profile, mProfile);
  }
}
