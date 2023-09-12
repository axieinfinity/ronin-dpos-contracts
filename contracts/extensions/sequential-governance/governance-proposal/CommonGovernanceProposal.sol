// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../CoreGovernance.sol";

abstract contract CommonGovernanceProposal is CoreGovernance {
  using Proposal for Proposal.ProposalDetail;

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
    uint256 _minimumAgainstVoteWeight = _getTotalWeight() - _minimumForVoteWeight + 1;

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
   * @dev Returns the voted signatures for the proposals.
   *
   * Note: The signatures can be empty in case the proposal is voted on the current network.
   *
   */
  function _getProposalSignatures(
    uint256 _chainId,
    uint256 _round
  )
    internal
    view
    returns (address[] memory _voters, Ballot.VoteType[] memory _supports, Signature[] memory _signatures)
  {
    ProposalVote storage _vote = vote[_chainId][_round];

    uint256 _forLength = _vote.forVoteds.length;
    uint256 _againstLength = _vote.againstVoteds.length;
    uint256 _voterLength = _forLength + _againstLength;

    _supports = new Ballot.VoteType[](_voterLength);
    _signatures = new Signature[](_voterLength);
    _voters = new address[](_voterLength);
    for (uint256 _i; _i < _forLength; ) {
      _supports[_i] = Ballot.VoteType.For;
      _signatures[_i] = vote[_chainId][_round].sig[_vote.forVoteds[_i]];
      _voters[_i] = _vote.forVoteds[_i];

      unchecked {
        ++_i;
      }
    }
    for (uint256 _i; _i < _againstLength; ) {
      _supports[_i + _forLength] = Ballot.VoteType.Against;
      _signatures[_i + _forLength] = vote[_chainId][_round].sig[_vote.againstVoteds[_i]];
      _voters[_i + _forLength] = _vote.againstVoteds[_i];

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @dev Returns whether the voter `_voter` casted vote for the proposal.
   */
  function _proposalVoted(uint256 _chainId, uint256 _round, address _voter) internal view returns (bool) {
    return _voted(vote[_chainId][_round], _voter);
  }

  /**
   * @dev Returns the weight of a governor.
   */
  function _getWeight(address _governor) internal view virtual returns (uint256);
}
