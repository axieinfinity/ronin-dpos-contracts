// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CoreGovernance.sol";

abstract contract GovernanceProposal is CoreGovernance {
  using Proposal for Proposal.ProposalDetail;
  using GlobalProposal for GlobalProposal.GlobalProposalDetail;

  /**
   * @dev Error thrown when an invalid proposal is encountered.
   * @param actual The actual value of the proposal.
   * @param expected The expected value of the proposal.
   */
  error ErrInvalidProposal(bytes32 actual, bytes32 expected);

  /**
   * @dev Casts votes by signatures.
   *
   * Note: This method does not verify the proposal hash with the vote hash. Please consider checking it before.
   *
   */
  function _castVotesBySignatures(
    Proposal.ProposalDetail memory _proposal,
    Ballot.VoteType[] calldata _supports,
    Signature[] calldata _signatures,
    bytes32 _forDigest,
    bytes32 _againstDigest
  ) internal {
    if (!(_supports.length != 0 && _supports.length == _signatures.length)) revert ErrLengthMismatch(msg.sig);

    uint256 _minimumForVoteWeight = _getMinimumVoteWeight();
    uint256 _minimumAgainstVoteWeight = _getTotalWeights() - _minimumForVoteWeight + 1;

    address _lastSigner;
    address _signer;
    Signature calldata _sig;
    bool _hasValidVotes;
    for (uint256 _i; _i < _signatures.length; ) {
      _sig = _signatures[_i];

      if (_supports[_i] == Ballot.VoteType.For) {
        _signer = ECDSA.recover(_forDigest, _sig.v, _sig.r, _sig.s);
      } else if (_supports[_i] == Ballot.VoteType.Against) {
        _signer = ECDSA.recover(_againstDigest, _sig.v, _sig.r, _sig.s);
      } else revert ErrUnsupportedVoteType(msg.sig);

      if (_lastSigner >= _signer) revert ErrInvalidOrder(msg.sig);
      _lastSigner = _signer;

      uint256 _weight = _getWeight(_signer);
      if (_weight > 0) {
        _hasValidVotes = true;
        if (
          _castVote(_proposal, _supports[_i], _minimumForVoteWeight, _minimumAgainstVoteWeight, _signer, _sig, _weight)
        ) {
          return;
        }
      }

      unchecked {
        ++_i;
      }
    }

    if (!_hasValidVotes) revert ErrInvalidSignatures(msg.sig);
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

  /**
   * @dev Proposes and votes by signature.
   */
  function _proposeGlobalProposalStructAndCastVotes(
    GlobalProposal.GlobalProposalDetail calldata _globalProposal,
    Ballot.VoteType[] calldata _supports,
    Signature[] calldata _signatures,
    bytes32 _domainSeparator,
    address _roninTrustedOrganizationContract,
    address _gatewayContract,
    address _creator
  ) internal returns (Proposal.ProposalDetail memory _proposal) {
    _proposal = _proposeGlobalStruct(_globalProposal, _roninTrustedOrganizationContract, _gatewayContract, _creator);
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
    address _roninTrustedOrganizationContract,
    address _gatewayContract
  ) internal {
    Proposal.ProposalDetail memory _proposal = _globalProposal.into_proposal_detail(
      _roninTrustedOrganizationContract,
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
   * @dev Returns the weight of a governor.
   */
  function _getWeight(address _governor) internal view virtual returns (uint256);
}
