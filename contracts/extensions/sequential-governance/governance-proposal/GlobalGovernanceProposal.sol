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
    GlobalProposal.GlobalProposalDetail calldata globalProposal,
    Ballot.VoteType[] calldata supports_,
    Signature[] calldata signatures,
    bytes32 domainSeparator,
    address creator
  ) internal returns (Proposal.ProposalDetail memory proposal) {
    proposal = _proposeGlobalStruct(globalProposal, creator);
    bytes32 _globalProposalHash = globalProposal.hash();
    _castVotesBySignatures(
      proposal,
      supports_,
      signatures,
      ECDSA.toTypedDataHash(domainSeparator, Ballot.hash(_globalProposalHash, Ballot.VoteType.For)),
      ECDSA.toTypedDataHash(domainSeparator, Ballot.hash(_globalProposalHash, Ballot.VoteType.Against))
    );
  }

  /**
   * @dev Proposes a global proposal struct and casts votes by signature.
   */
  function _castGlobalProposalBySignatures(
    GlobalProposal.GlobalProposalDetail calldata globalProposal,
    Ballot.VoteType[] calldata supports_,
    Signature[] calldata signatures,
    bytes32 domainSeparator
  ) internal {
    Proposal.ProposalDetail memory _proposal = globalProposal.intoProposalDetail(
      _resolveTargets({ targetOptions: globalProposal.targetOptions, strict: true })
    );

    bytes32 proposalHash = _proposal.hash();
    if (vote[0][_proposal.nonce].hash != proposalHash)
      revert ErrInvalidProposal(proposalHash, vote[0][_proposal.nonce].hash);

    bytes32 globalProposalHash = globalProposal.hash();
    _castVotesBySignatures(
      _proposal,
      supports_,
      signatures,
      ECDSA.toTypedDataHash(domainSeparator, Ballot.hash(globalProposalHash, Ballot.VoteType.For)),
      ECDSA.toTypedDataHash(domainSeparator, Ballot.hash(globalProposalHash, Ballot.VoteType.Against))
    );
  }

  /**
   * @dev See {CommonGovernanceProposal-_getProposalSignatures}
   */
  function getGlobalProposalSignatures(
    uint256 round_
  ) external view returns (address[] memory voters, Ballot.VoteType[] memory supports_, Signature[] memory signatures) {
    return _getProposalSignatures(0, round_);
  }

  /**
   * @dev See {CommonGovernanceProposal-_proposalVoted}
   */
  function globalProposalVoted(uint256 round_, address voter) external view returns (bool) {
    return _proposalVoted(0, round_, voter);
  }
}
