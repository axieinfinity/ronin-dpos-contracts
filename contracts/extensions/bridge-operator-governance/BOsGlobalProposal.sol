// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { Proposal, GlobalProposal, CoreGlobalProposal } from "../sequential-governance/CoreGlobalProposal.sol";
import { Ballot } from "../../libraries/Ballot.sol";

abstract contract BOsGlobalProposal is CoreGlobalProposal {
  using Proposal for Proposal.ProposalDetail;
  using GlobalProposal for GlobalProposal.GlobalProposalDetail;

  constructor(uint256 expiryDuration) CoreGlobalProposal(expiryDuration) {}

  /**
   * @dev Proposes and votes by signature.
   */
  function _proposeGlobalProposalStructAndCastVotes(
    GlobalProposal.GlobalProposalDetail calldata _globalProposal,
    Ballot.VoteType[] calldata _supports,
    Signature[] calldata _signatures,
    bytes32 _domainSeparator,
    address _bridgeManagerContract,
    address _gatewayContract,
    address _creator
  ) internal returns (Proposal.ProposalDetail memory _proposal) {
    _proposal = _proposeGlobalStruct(_globalProposal, _bridgeManagerContract, _gatewayContract, _creator);
    bytes32 _globalProposalHash = _globalProposal.hash();
    _castVotesBySignatures(
      _proposal,
      _supports,
      _signatures,
      ECDSA.toTypedDataHash(_domainSeparator, Ballot.hash(_globalProposalHash, Ballot.VoteType.For)),
      ECDSA.toTypedDataHash(_domainSeparator, Ballot.hash(_globalProposalHash, Ballot.VoteType.Against))
    );
  }

  /**
   * @dev Proposes a global proposal struct and casts votes by signature.
   */
  function _castGlobalProposalBySignatures(
    GlobalProposal.GlobalProposalDetail calldata _globalProposal,
    Ballot.VoteType[] calldata _supports,
    Signature[] calldata _signatures,
    bytes32 _domainSeparator,
    address _bridgeManagerContract,
    address _gatewayContract
  ) internal {
    Proposal.ProposalDetail memory _proposal = _globalProposal.intoProposalDetail(
      _bridgeManagerContract,
      _gatewayContract
    );
    bytes32 _proposalHash = _proposal.hash();
    if (vote[0][_proposal.nonce].hash != _proposalHash)
      revert ErrInvalidProposal(_proposalHash, vote[0][_proposal.nonce].hash);

    bytes32 _globalProposalHash = _globalProposal.hash();
    _castVotesBySignatures(
      _proposal,
      _supports,
      _signatures,
      ECDSA.toTypedDataHash(_domainSeparator, Ballot.hash(_globalProposalHash, Ballot.VoteType.For)),
      ECDSA.toTypedDataHash(_domainSeparator, Ballot.hash(_globalProposalHash, Ballot.VoteType.Against))
    );
  }

  /**
   * @dev Proposes for a global proposal.
   *
   * Emits the `GlobalProposalCreated` event.
   *
   */
  function _proposeGlobal(
    uint256 _expiryTimestamp,
    GlobalProposal.TargetOption[] calldata _targetOptions,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    uint256[] memory _gasAmounts,
    address _bridgeManagerContract,
    address _gatewayContract,
    address _creator
  ) internal virtual {
    uint256 _round = _createVotingRound(0);
    GlobalProposal.GlobalProposalDetail memory _globalProposal = GlobalProposal.GlobalProposalDetail(
      _round,
      _expiryTimestamp,
      _targetOptions,
      _values,
      _calldatas,
      _gasAmounts
    );
    Proposal.ProposalDetail memory _proposal = _globalProposal.intoProposalDetail(
      _bridgeManagerContract,
      _gatewayContract
    );
    _proposal.validate(_proposalExpiryDuration);

    bytes32 _proposalHash = _proposal.hash();
    _saveVotingRound(vote[0][_round], _proposalHash, _expiryTimestamp);
    emit GlobalProposalCreated(_round, _proposalHash, _proposal, _globalProposal.hash(), _globalProposal, _creator);
  }
}
