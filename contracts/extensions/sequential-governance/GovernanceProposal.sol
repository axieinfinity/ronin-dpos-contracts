// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CoreGovernance.sol";

abstract contract GovernanceProposal is CoreGovernance {
  using Proposal for Proposal.ProposalDetail;

  /// @dev Emitted when a proposal is created
  event ProposalCreated(
    uint256 indexed chainId,
    uint256 indexed round,
    bytes32 indexed proposalHash,
    Proposal.ProposalDetail proposal,
    address creator
  );

  /**
   * @dev Proposes for a new proposal.
   *
   * Requirements:
   * - The chain id is not equal to 0.
   *
   * Emits the `ProposalCreated` event.
   *
   */
  function _proposeProposal(
    uint256 _chainId,
    uint256 _expiryTimestamp,
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    uint256[] memory _gasAmounts,
    address _creator
  ) internal virtual returns (Proposal.ProposalDetail memory _proposal) {
    if (_chainId == 0) revert ErrInvalidChainId(msg.sig, 0, block.chainid);
    uint256 _round = _createVotingRound(_chainId);

    _proposal = Proposal.ProposalDetail(_round, _chainId, _expiryTimestamp, _targets, _values, _calldatas, _gasAmounts);
    _proposal.validate(_proposalExpiryDuration);

    bytes32 _proposalHash = _proposal.hash();
    _saveVotingRound(vote[_chainId][_round], _proposalHash, _expiryTimestamp);
    emit ProposalCreated(_chainId, _round, _proposalHash, _proposal, _creator);
  }

  /**
   * @dev Proposes proposal struct.
   *
   * Requirements:
   * - The chain id is not equal to 0.
   * - The proposal nonce is equal to the new round.
   *
   * Emits the `ProposalCreated` event.
   *
   */
  function _proposeProposalStruct(
    Proposal.ProposalDetail memory _proposal,
    address _creator
  ) internal virtual returns (uint256 _round) {
    uint256 _chainId = _proposal.chainId;
    if (_chainId == 0) revert ErrInvalidChainId(msg.sig, 0, block.chainid);
    _proposal.validate(_proposalExpiryDuration);

    bytes32 _proposalHash = _proposal.hash();
    _round = _createVotingRound(_chainId);
    _saveVotingRound(vote[_chainId][_round], _proposalHash, _proposal.expiryTimestamp);
    if (_round != _proposal.nonce) revert ErrInvalidProposalNonce(msg.sig);
    emit ProposalCreated(_chainId, _round, _proposalHash, _proposal, _creator);
  }

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
}
