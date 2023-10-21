// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../CoreGovernance.sol";
import "./CommonGovernanceRelay.sol";

abstract contract GovernanceRelay is CoreGovernance, CommonGovernanceRelay {
  using Proposal for Proposal.ProposalDetail;
  using GlobalProposal for GlobalProposal.GlobalProposalDetail;

  /**
   * @dev Relays voted proposal.
   *
   * Requirements:
   * - The relay proposal is finalized.
   *
   */
  function _relayProposal(
    Proposal.ProposalDetail calldata _proposal,
    Ballot.VoteType[] calldata _supports,
    Signature[] calldata _signatures,
    bytes32 _domainSeparator,
    address _creator
  ) internal {
    _proposeProposalStruct(_proposal, _creator);
    bytes32 _proposalHash = _proposal.hash();
    _relayVotesBySignatures(
      _proposal,
      _supports,
      _signatures,
      ECDSA.toTypedDataHash(_domainSeparator, Ballot.hash(_proposalHash, Ballot.VoteType.For)),
      ECDSA.toTypedDataHash(_domainSeparator, Ballot.hash(_proposalHash, Ballot.VoteType.Against))
    );
  }
}
