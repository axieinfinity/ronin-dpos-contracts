// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../CoreGovernance.sol";
import "./CommonGovernanceProposal.sol";

abstract contract GovernanceProposal is CoreGovernance, CommonGovernanceProposal {
  using Proposal for Proposal.ProposalDetail;

  /**
   * @dev Proposes a proposal struct and casts votes by signature.
   */
  function _proposeProposalStructAndCastVotes(
    Proposal.ProposalDetail calldata _proposal,
    Ballot.VoteType[] calldata _supports,
    Signature[] calldata _signatures,
    bytes32 _domainSeparator,
    address _creator
  ) internal {
    _proposeProposalStruct(_proposal, _creator);
    bytes32 _proposalHash = _proposal.hash();
    _castVotesBySignatures(
      _proposal,
      _supports,
      _signatures,
      ECDSA.toTypedDataHash(_domainSeparator, Ballot.hash(_proposalHash, Ballot.VoteType.For)),
      ECDSA.toTypedDataHash(_domainSeparator, Ballot.hash(_proposalHash, Ballot.VoteType.Against))
    );
  }

  /**
   * @dev Proposes a proposal struct and casts votes by signature.
   */
  function _castProposalBySignatures(
    Proposal.ProposalDetail calldata _proposal,
    Ballot.VoteType[] calldata _supports,
    Signature[] calldata _signatures,
    bytes32 _domainSeparator
  ) internal {
    bytes32 _proposalHash = _proposal.hash();

    if (vote[_proposal.chainId][_proposal.nonce].hash != _proposalHash) {
      revert ErrInvalidProposal(_proposalHash, vote[_proposal.chainId][_proposal.nonce].hash);
    }

    _castVotesBySignatures(
      _proposal,
      _supports,
      _signatures,
      ECDSA.toTypedDataHash(_domainSeparator, Ballot.hash(_proposalHash, Ballot.VoteType.For)),
      ECDSA.toTypedDataHash(_domainSeparator, Ballot.hash(_proposalHash, Ballot.VoteType.Against))
    );
  }

  /**
   * @dev See {CommonGovernanceProposal-_getProposalSignatures}
   */
  function getProposalSignatures(
    uint256 _chainId,
    uint256 _round
  )
    external
    view
    returns (address[] memory _voters, Ballot.VoteType[] memory _supports, Signature[] memory _signatures)
  {
    return _getProposalSignatures(_chainId, _round);
  }

  /**
   * @dev See {CommonGovernanceProposal-_proposalVoted}
   */
  function proposalVoted(uint256 _chainId, uint256 _round, address _voter) external view returns (bool) {
    return _proposalVoted(_chainId, _round, _voter);
  }
}
