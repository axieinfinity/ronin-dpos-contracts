// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { Proposal, GlobalProposal, CoreGlobalProposal } from "./CoreGlobalProposal.sol";
import { Ballot } from "../../libraries/Ballot.sol";
import { ErrInvalidVoteWeight, ErrRelayFailed, ErrInvalidOrder, ErrUnsupportedVoteType, ErrLengthMismatch } from "../../utils/CommonErrors.sol";

abstract contract GovernanceRelay is CoreGlobalProposal {
  using GlobalProposal for GlobalProposal.GlobalProposalDetail;

  constructor(uint256 expiryDuration) CoreGlobalProposal(expiryDuration) {}

  /**
   * @dev Relays votes by signatures.
   *
   * @notice Does not store the voter signature into storage.
   *
   */
  function _relayVotesBySignatures(
    Proposal.ProposalDetail memory _proposal,
    Ballot.VoteType[] calldata _supports,
    Signature[] calldata _signatures,
    bytes32 _forDigest,
    bytes32 _againstDigest
  ) internal {
    if (!(_supports.length > 0 && _supports.length == _signatures.length)) revert ErrLengthMismatch(msg.sig);

    uint256 _forVoteCount;
    uint256 _againstVoteCount;
    address[] memory _forVoteSigners = new address[](_signatures.length);
    address[] memory _againstVoteSigners = new address[](_signatures.length);

    {
      address _signer;
      address _lastSigner;
      Ballot.VoteType _support;
      Signature calldata _sig;

      for (uint256 _i; _i < _signatures.length; ) {
        _sig = _signatures[_i];
        _support = _supports[_i];

        if (_support == Ballot.VoteType.For) {
          _signer = ECDSA.recover(_forDigest, _sig.v, _sig.r, _sig.s);
          _forVoteSigners[_forVoteCount++] = _signer;
        } else if (_support == Ballot.VoteType.Against) {
          _signer = ECDSA.recover(_againstDigest, _sig.v, _sig.r, _sig.s);
          _againstVoteSigners[_againstVoteCount++] = _signer;
        } else revert ErrUnsupportedVoteType(msg.sig);

        if (_lastSigner >= _signer) revert ErrInvalidOrder(msg.sig);
        _lastSigner = _signer;

        unchecked {
          ++_i;
        }
      }
    }

    assembly {
      mstore(_forVoteSigners, _forVoteCount)
      mstore(_againstVoteSigners, _againstVoteCount)
    }

    ProposalVote storage _vote = vote[_proposal.chainId][_proposal.nonce];
    uint256 _minimumForVoteWeight = _getMinimumVoteWeight();
    uint256 _totalForVoteWeight = _sumWeights(_forVoteSigners);
    if (_totalForVoteWeight >= _minimumForVoteWeight) {
      if (_totalForVoteWeight == 0) revert ErrInvalidVoteWeight(msg.sig);
      _vote.status = VoteStatus.Approved;
      emit ProposalApproved(_vote.hash);
      _tryExecute(_vote, _proposal);
      return;
    }

    uint256 _minimumAgainstVoteWeight = _getTotalWeights() - _minimumForVoteWeight + 1;
    uint256 _totalAgainstVoteWeight = _sumWeights(_againstVoteSigners);
    if (_totalAgainstVoteWeight >= _minimumAgainstVoteWeight) {
      if (_totalAgainstVoteWeight == 0) revert ErrInvalidVoteWeight(msg.sig);
      _vote.status = VoteStatus.Rejected;
      emit ProposalRejected(_vote.hash);
      return;
    }

    revert ErrRelayFailed(msg.sig);
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

  /**
   * @dev Returns the weight of the governor list.
   */
  function _sumWeights(address[] memory _governors) internal view virtual returns (uint256);
}
