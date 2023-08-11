// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../libraries/Proposal.sol";
import "../../libraries/GlobalProposal.sol";
import "../../utils/CommonErrors.sol";
import "../../libraries/Ballot.sol";
import "../../interfaces/consumers/ChainTypeConsumer.sol";
import "../../interfaces/consumers/SignatureConsumer.sol";
import "../../interfaces/consumers/VoteStatusConsumer.sol";

abstract contract CoreGovernance is SignatureConsumer, VoteStatusConsumer, ChainTypeConsumer {
  using Proposal for Proposal.ProposalDetail;

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

  /// @dev Emitted when a proposal is created
  event ProposalCreated(
    uint256 indexed chainId,
    uint256 indexed round,
    bytes32 indexed proposalHash,
    Proposal.ProposalDetail proposal,
    address creator
  );
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
  /// @dev Emitted when the proposal expiry duration is changed.
  event ProposalExpiryDurationChanged(uint256 indexed duration);

  /// @dev Mapping from chain id => vote round
  /// @notice chain id = 0 for global proposal
  mapping(uint256 => uint256) public round;
  /// @dev Mapping from chain id => vote round => proposal vote
  mapping(uint256 => mapping(uint256 => ProposalVote)) public vote;

  uint256 internal _proposalExpiryDuration;

  constructor(uint256 _expiryDuration) {
    _setProposalExpiryDuration(_expiryDuration);
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
   * @dev Proposes for a new proposal.
   *
   * Requirements:
   * - The chain id is not equal to 0.
   *
   * Emits the `ProposalCreated` event.
   *
   */
  function _proposeProposal(
    uint256 chainId,
    uint256 expiryTimestamp,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    uint256[] memory gasAmounts,
    address creator
  ) internal virtual returns (Proposal.ProposalDetail memory proposal) {
    if (chainId == 0) revert ErrInvalidChainId(msg.sig, 0, block.chainid);
    uint256 round_ = _createVotingRound(chainId);

    proposal = Proposal.ProposalDetail(round_, chainId, expiryTimestamp, targets, values, calldatas, gasAmounts);
    proposal.validate(_proposalExpiryDuration);

    bytes32 proposalHash = proposal.hash();
    _saveVotingRound(vote[chainId][round_], proposalHash, expiryTimestamp);
    emit ProposalCreated(chainId, round_, proposalHash, proposal, creator);
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
    Proposal.ProposalDetail memory proposal,
    address creator
  ) internal virtual returns (uint256 round_) {
    uint256 chainId = proposal.chainId;
    if (chainId == 0) revert ErrInvalidChainId(msg.sig, 0, block.chainid);
    proposal.validate(_proposalExpiryDuration);

    bytes32 proposalHash = proposal.hash();
    round_ = _createVotingRound(chainId);
    _saveVotingRound(vote[chainId][round_], proposalHash, proposal.expiryTimestamp);
    if (round_ != proposal.nonce) revert ErrInvalidProposalNonce(msg.sig);
    emit ProposalCreated(chainId, round_, proposalHash, proposal, creator);
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
    Proposal.ProposalDetail memory proposal,
    Ballot.VoteType support,
    uint256 minimumForVoteWeight,
    uint256 minimumAgainstVoteWeight,
    address voter,
    Signature memory signature,
    uint256 voterWeight
  ) internal virtual returns (bool done) {
    uint256 chainId = proposal.chainId;
    uint256 round_ = proposal.nonce;
    ProposalVote storage _vote = vote[chainId][round_];

    if (_tryDeleteExpiredVotingRound(_vote)) {
      return true;
    }

    if (round[proposal.chainId] != round_) revert ErrInvalidProposalNonce(msg.sig);
    if (_vote.status != VoteStatus.Pending) revert ErrVoteIsFinalized();
    if (_voted(_vote, voter)) revert ErrAlreadyVoted(voter);

    _vote.voted[voter] = true;
    // Stores the signature if it is not empty
    if (signature.r > 0 || signature.s > 0 || signature.v > 0) {
      _vote.sig[voter] = signature;
    }
    emit ProposalVoted(_vote.hash, voter, support, voterWeight);

    uint256 _forVoteWeight;
    uint256 _againstVoteWeight;
    if (support == Ballot.VoteType.For) {
      _vote.forVoteds.push(voter);
      _forVoteWeight = _vote.forVoteWeight += voterWeight;
    } else if (support == Ballot.VoteType.Against) {
      _vote.againstVoteds.push(voter);
      _againstVoteWeight = _vote.againstVoteWeight += voterWeight;
    } else revert ErrUnsupportedVoteType(msg.sig);

    if (_forVoteWeight >= minimumForVoteWeight) {
      done = true;
      _vote.status = VoteStatus.Approved;
      emit ProposalApproved(_vote.hash);
      _tryExecute(_vote, proposal);
    } else if (_againstVoteWeight >= minimumAgainstVoteWeight) {
      done = true;
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
  function _tryDeleteExpiredVotingRound(ProposalVote storage proposalVote) internal returns (bool isExpired) {
    isExpired =
      _getChainType() == ChainType.RoninChain &&
      proposalVote.status == VoteStatus.Pending &&
      proposalVote.expiryTimestamp <= block.timestamp;

    if (isExpired) {
      emit ProposalExpired(proposalVote.hash);

      for (uint256 _i; _i < proposalVote.forVoteds.length; ) {
        delete proposalVote.voted[proposalVote.forVoteds[_i]];
        delete proposalVote.sig[proposalVote.forVoteds[_i]];

        unchecked {
          ++_i;
        }
      }
      for (uint256 _i; _i < proposalVote.againstVoteds.length; ) {
        delete proposalVote.voted[proposalVote.againstVoteds[_i]];
        delete proposalVote.sig[proposalVote.againstVoteds[_i]];

        unchecked {
          ++_i;
        }
      }
      delete proposalVote.status;
      delete proposalVote.hash;
      delete proposalVote.againstVoteWeight;
      delete proposalVote.forVoteWeight;
      delete proposalVote.forVoteds;
      delete proposalVote.againstVoteds;
      delete proposalVote.expiryTimestamp;
    }
  }

  /**
   * @dev Executes the proposal and update the vote status once the proposal is executable.
   */
  function _tryExecute(ProposalVote storage vote_, Proposal.ProposalDetail memory proposal) internal {
    if (proposal.executable()) {
      vote_.status = VoteStatus.Executed;
      (bool[] memory _successCalls, bytes[] memory _returnDatas) = proposal.execute();
      emit ProposalExecuted(vote_.hash, _successCalls, _returnDatas);
    }
  }

  /**
   * @dev Sets the expiry duration for a new proposal.
   */
  function _setProposalExpiryDuration(uint256 expiryDuration) internal {
    _proposalExpiryDuration = expiryDuration;
    emit ProposalExpiryDurationChanged(expiryDuration);
  }

  /**
   * @dev Returns the expiry duration for a new proposal.
   */
  function _getProposalExpiryDuration() internal view returns (uint256) {
    return _proposalExpiryDuration;
  }

  /**
   * @dev Returns whether the voter casted for the proposal.
   */
  function _voted(ProposalVote storage vote_, address voter) internal view returns (bool) {
    return vote_.voted[voter];
  }

  /**
   * @dev Returns total weight from validators.
   */
  function _getTotalWeight() internal view virtual returns (uint256);

  /**
   * @dev Returns minimum vote to pass a proposal.
   */
  function _getMinimumVoteWeight() internal view virtual returns (uint256);

  /**
   * @dev Returns current context is running on whether Ronin chain or on mainchain.
   */
  function _getChainType() internal view virtual returns (ChainType);
}
