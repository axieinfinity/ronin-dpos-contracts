// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../libraries/Proposal.sol";
import "../GlobalCoreGovernance.sol";
import "./CommonGovernanceProposal.sol";

abstract contract GlobalGovernanceProposal is GlobalCoreGovernance, CommonGovernanceProposal {
  using Proposal for Proposal.ProposalDetail;
  using GlobalProposal for GlobalProposal.GlobalProposalDetail;

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
}
