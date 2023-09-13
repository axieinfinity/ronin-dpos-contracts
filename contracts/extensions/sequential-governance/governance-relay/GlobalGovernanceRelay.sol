// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../GlobalCoreGovernance.sol";
import "./CommonGovernanceRelay.sol";

abstract contract GlobalGovernanceRelay is CommonGovernanceRelay, GlobalCoreGovernance {
  using GlobalProposal for GlobalProposal.GlobalProposalDetail;

  /**
   * @dev Returns whether the voter `_voter` casted vote for the proposal.
   */
  function globalProposalRelayed(uint256 _round) external view returns (bool) {
    return vote[0][_round].status != VoteStatus.Pending;
  }

  /**
   * @dev Relays voted global proposal.
   *
   * Requirements:
   * - The relay proposal is finalized.
   *
   */
  function _relayGlobalProposal(
    GlobalProposal.GlobalProposalDetail calldata globalProposal,
    Ballot.VoteType[] calldata supports_,
    Signature[] calldata signatures,
    bytes32 domainSeparator,
    address creator
  ) internal {
    Proposal.ProposalDetail memory _proposal = _proposeGlobalStruct(globalProposal, creator);
    bytes32 globalProposalHash = globalProposal.hash();
    _relayVotesBySignatures(
      _proposal,
      supports_,
      signatures,
      ECDSA.toTypedDataHash(domainSeparator, Ballot.hash(globalProposalHash, Ballot.VoteType.For)),
      ECDSA.toTypedDataHash(domainSeparator, Ballot.hash(globalProposalHash, Ballot.VoteType.Against))
    );
  }
}
