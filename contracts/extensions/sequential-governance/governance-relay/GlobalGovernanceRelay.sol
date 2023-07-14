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
    GlobalProposal.GlobalProposalDetail calldata _globalProposal,
    Ballot.VoteType[] calldata _supports,
    Signature[] calldata _signatures,
    bytes32 _domainSeparator,
    address _bridgeManager,
    address _gatewayContract,
    address _creator
  ) internal {
    Proposal.ProposalDetail memory _proposal = _proposeGlobalStruct(
      _globalProposal,
      _bridgeManager,
      _gatewayContract,
      _creator
    );
    bytes32 _globalProposalHash = _globalProposal.hash();
    _relayVotesBySignatures(
      _proposal,
      _supports,
      _signatures,
      ECDSA.toTypedDataHash(_domainSeparator, Ballot.hash(_globalProposalHash, Ballot.VoteType.For)),
      ECDSA.toTypedDataHash(_domainSeparator, Ballot.hash(_globalProposalHash, Ballot.VoteType.Against))
    );
  }
}
