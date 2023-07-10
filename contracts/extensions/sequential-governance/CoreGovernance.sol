// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../libraries/Proposal.sol";
import "../../utils/CommonErrors.sol";
import "../../libraries/Ballot.sol";
import "../../interfaces/consumers/ChainTypeConsumer.sol";
import "../../interfaces/consumers/SignatureConsumer.sol";
import "../../interfaces/consumers/VoteStatusConsumer.sol";

abstract contract CoreGovernance is SignatureConsumer, VoteStatusConsumer, ChainTypeConsumer {
  using Proposal for Proposal.ProposalDetail;

  /**
   * @dev Error thrown when an invalid proposal is encountered.
   * @param actual The actual value of the proposal.
   * @param expected The expected value of the proposal.
   */
  error ErrInvalidProposal(bytes32 actual, bytes32 expected);

  /**
   * @dev Error thrown when attempting to interact with a finalized vote.
   */
  error ErrVoteIsFinalized();

  /**
   * @dev Error thrown when the current proposal is not completed.
   */
  error ErrCurrentProposalIsNotCompleted();

  struct ProposalVote {
    VoteStatus status;
    bytes32 hash;
    uint256 againstVoteWeight; // Total weight of against votes
    uint256 forVoteWeight; // Total weight of for votes
    address[] forVoteds; // Array of addresses voting for
    address[] againstVoteds; // Array of addresses voting against
    uint256 expiryTimestamp;
    mapping(address => Signature) sig;
    mapping(address => bool) voted;
  }

  /// @dev Emitted when the proposal is voted
  event ProposalVoted(bytes32 indexed proposalHash, address indexed voter, Ballot.VoteType support, uint256 weight);
  /// @dev Emitted when the proposal is approved
  event ProposalApproved(bytes32 indexed proposalHash);
  /// @dev Emitted when the vote is reject
  event ProposalRejected(bytes32 indexed proposalHash);
  /// @dev Emitted when the vote is expired
  event ProposalExpired(bytes32 indexed proposalHash);
  /// @dev Emitted when the proposal is executed
  event ProposalExecuted(bytes32 indexed proposalHash, bool[] successCalls, bytes[] returnDatas);

  /// @dev Mapping from chain id => vote round
  /// @notice chain id = 0 for global proposal
  mapping(uint256 => uint256) public round;
  /// @dev Mapping from chain id => vote round => proposal vote
  mapping(uint256 => mapping(uint256 => ProposalVote)) public vote;

  uint256 internal _proposalExpiryDuration;

  constructor(uint256 expiryDuration) {
    _setProposalExpiryDuration(expiryDuration);
  }

  /**
   * @dev Returns the expiry duration for a new proposal.
   */
  function _getProposalExpiryDuration() internal view returns (uint256) {
    return _proposalExpiryDuration;
  }

  /**
   * @dev Sets the expiry duration for a new proposal.
   */
  function _setProposalExpiryDuration(uint256 _expiryDuration) internal {
    _proposalExpiryDuration = _expiryDuration;
  }

  /**
   * @dev Creates new voting round by calculating the `_round` number of chain `_chainId`.
   * Increases the `_round` number if the previous one is not expired. Delete the previous proposal
   * if it is expired and not increase the `_round`.
   */
  function _createVotingRound(uint256 _chainId) internal returns (uint256 _round) {
    _round = round[_chainId];
    // Skip checking for the first ever round
    if (_round == 0) {
      _round = round[_chainId] = 1;
    } else {
      ProposalVote storage _latestProposalVote = vote[_chainId][_round];
      bool _isExpired = _tryDeleteExpiredVotingRound(_latestProposalVote);
      // Skip increasing round number if the latest round is expired, allow the vote to be overridden
      if (!_isExpired) {
        if (_latestProposalVote.status == VoteStatus.Pending) revert ErrCurrentProposalIsNotCompleted();
        unchecked {
          _round = ++round[_chainId];
        }
      }
    }
  }

  /**
   * @dev Saves new round voting for the proposal `_proposalHash` of chain `_chainId`.
   */
  function _saveVotingRound(ProposalVote storage _vote, bytes32 _proposalHash, uint256 _expiryTimestamp) internal {
    _vote.hash = _proposalHash;
    _vote.expiryTimestamp = _expiryTimestamp;
  }

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
   * @dev Casts vote for the proposal with data and returns whether the voting is done.
   *
   * Requirements:
   * - The proposal nonce is equal to the round.
   * - The vote is not finalized.
   * - The voter has not voted for the round.
   *
   * Emits the `ProposalVoted` event. Emits the `ProposalApproved`, `ProposalExecuted` or `ProposalRejected` once the
   * proposal is approved, executed or rejected.
   *
   */
  function _castVote(
    Proposal.ProposalDetail memory _proposal,
    Ballot.VoteType _support,
    uint256 _minimumForVoteWeight,
    uint256 _minimumAgainstVoteWeight,
    address _voter,
    Signature memory _signature,
    uint256 _voterWeight
  ) internal virtual returns (bool _done) {
    uint256 _chainId = _proposal.chainId;
    uint256 _round = _proposal.nonce;
    ProposalVote storage _vote = vote[_chainId][_round];

    if (_tryDeleteExpiredVotingRound(_vote)) {
      return true;
    }

    if (round[_proposal.chainId] != _round) revert ErrInvalidProposalNonce(msg.sig);
    if (_vote.status != VoteStatus.Pending) revert ErrVoteIsFinalized();
    if (_voted(_vote, _voter)) revert ErrAlreadyVoted(_voter);

    _vote.voted[_voter] = true;
    // Stores the signature if it is not empty
    if (_signature.r > 0 || _signature.s > 0 || _signature.v > 0) {
      _vote.sig[_voter] = _signature;
    }
    emit ProposalVoted(_vote.hash, _voter, _support, _voterWeight);

    uint256 _forVoteWeight;
    uint256 _againstVoteWeight;
    if (_support == Ballot.VoteType.For) {
      _vote.forVoteds.push(_voter);
      _forVoteWeight = _vote.forVoteWeight += _voterWeight;
    } else if (_support == Ballot.VoteType.Against) {
      _vote.againstVoteds.push(_voter);
      _againstVoteWeight = _vote.againstVoteWeight += _voterWeight;
    } else revert ErrUnsupportedVoteType(msg.sig);

    if (_forVoteWeight >= _minimumForVoteWeight) {
      _done = true;
      _vote.status = VoteStatus.Approved;
      emit ProposalApproved(_vote.hash);
      _tryExecute(_vote, _proposal);
    } else if (_againstVoteWeight >= _minimumAgainstVoteWeight) {
      _done = true;
      _vote.status = VoteStatus.Rejected;
      emit ProposalRejected(_vote.hash);
    }
  }

  /**
   * @dev When the contract is on Ronin chain, checks whether the proposal is expired and delete it if is expired.
   *
   * Emits the event `ProposalExpired` if the vote is expired.
   *
   * Note: This function assumes the vote `_proposalVote` is already created, consider verifying the vote's existence
   * before or it will emit an unexpected event of `ProposalExpired`.
   */
  function _tryDeleteExpiredVotingRound(ProposalVote storage _proposalVote) internal returns (bool _isExpired) {
    _isExpired =
      _getChainType() == ChainType.RoninChain &&
      _proposalVote.status == VoteStatus.Pending &&
      _proposalVote.expiryTimestamp <= block.timestamp;

    if (_isExpired) {
      emit ProposalExpired(_proposalVote.hash);

      for (uint256 _i; _i < _proposalVote.forVoteds.length; ) {
        delete _proposalVote.voted[_proposalVote.forVoteds[_i]];
        delete _proposalVote.sig[_proposalVote.forVoteds[_i]];

        unchecked {
          ++_i;
        }
      }
      for (uint256 _i; _i < _proposalVote.againstVoteds.length; ) {
        delete _proposalVote.voted[_proposalVote.againstVoteds[_i]];
        delete _proposalVote.sig[_proposalVote.againstVoteds[_i]];

        unchecked {
          ++_i;
        }
      }
      delete _proposalVote.status;
      delete _proposalVote.hash;
      delete _proposalVote.againstVoteWeight;
      delete _proposalVote.forVoteWeight;
      delete _proposalVote.forVoteds;
      delete _proposalVote.againstVoteds;
      delete _proposalVote.expiryTimestamp;
    }
  }

  /**
   * @dev Executes the proposal and update the vote status once the proposal is executable.
   */
  function _tryExecute(ProposalVote storage _vote, Proposal.ProposalDetail memory _proposal) internal {
    if (_proposal.executable()) {
      _vote.status = VoteStatus.Executed;
      (bool[] memory _successCalls, bytes[] memory _returnDatas) = _proposal.execute();
      emit ProposalExecuted(_vote.hash, _successCalls, _returnDatas);
    }
  }

  /**
   * @dev Returns whether the voter casted for the proposal.
   */
  function _voted(ProposalVote storage _vote, address _voter) internal view returns (bool) {
    return _vote.voted[_voter];
  }

  /**
   * @dev Returns total weight from validators.
   */
  function _getTotalWeights() internal view virtual returns (uint256);

  /**
   * @dev Returns minimum vote to pass a proposal.
   */
  function _getMinimumVoteWeight() internal view virtual returns (uint256);

  /**
   * @dev Returns current context is running on whether Ronin chain or on mainchain.
   */
  function _getChainType() internal view virtual returns (ChainType);

  /**
   * @dev Returns the weight of a governor.
   */
  function _getWeight(address _governor) internal view virtual returns (uint256);
}
