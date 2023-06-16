// SPDX-License-Identifier: MIT

import "./ProfileStorage.sol";
import "../../extensions/collections/HasContracts.sol";
import { ContractType } from "../../utils/ContractType.sol";

pragma solidity ^0.8.9;

abstract contract ProfileOutflow is HasContracts, ProfileStorage {
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
