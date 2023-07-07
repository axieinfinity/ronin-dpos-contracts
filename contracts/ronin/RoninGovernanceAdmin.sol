// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../extensions/sequential-governance/GovernanceProposal.sol";
import "../extensions/collections/HasContracts.sol";
import "../extensions/GovernanceAdmin.sol";
import "../libraries/EmergencyExitBallot.sol";
import { ErrorHandler } from "../libraries/ErrorHandler.sol";
import { IsolatedGovernance } from "../libraries/IsolatedGovernance.sol";
import { HasValidatorDeprecated } from "../utils/DeprecatedSlots.sol";
import "../interfaces/IRoninTrustedOrganization.sol";
import "../interfaces/validator/IRoninValidatorSet.sol";
import "../interfaces/IRoninGovernanceAdmin.sol";

contract RoninGovernanceAdmin is
  HasContracts,
  IRoninGovernanceAdmin,
  GovernanceAdmin,
  GovernanceProposal,
  HasValidatorDeprecated
{
  using ErrorHandler for bool;
  using Proposal for Proposal.ProposalDetail;
  using IsolatedGovernance for IsolatedGovernance.Vote;

  /// @dev Mapping from request hash => emergency poll
  mapping(bytes32 => IsolatedGovernance.Vote) internal _emergencyExitPoll;

  modifier onlyGovernor() {
    _requireGorvernor();
    _;
  }

  constructor(
    uint256 _roninChainId,
    address _roninTrustedOrganizationContract,
    address _validatorContract,
    uint256 _proposalExpiryDuration
  ) GovernanceAdmin(_roninChainId, _roninTrustedOrganizationContract, _proposalExpiryDuration) {
    _setContract(ContractType.VALIDATOR, _validatorContract);
  }

  function _requireGorvernor() private view {
    if (_getWeight(msg.sender) == 0) revert ErrUnauthorized(msg.sig, RoleAccess.GOVERNOR);
  }

  /**
   * @inheritdoc IHasContracts
   */
  function setContract(
    ContractType contractType,
    address addr
  ) external override(HasContracts, GovernanceAdmin) onlySelfCall {
    _requireHasCode(addr);
    _setContract(contractType, addr);
  }

  /**
   * @dev Returns the voted signatures for the proposals.
   *
   * Note: The signatures can be empty in case the proposal is voted on the current network.
   *
   */
  function getProposalSignatures(
    uint256 _chainId,
    uint256 _round
  )
    external
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
  function proposalVoted(uint256 _chainId, uint256 _round, address _voter) external view returns (bool) {
    return _voted(vote[_chainId][_round], _voter);
  }

  /**
   * @dev Returns whether the voter casted vote for emergency exit poll.
   */
  function emergencyPollVoted(bytes32 _voteHash, address _voter) external view returns (bool) {
    return _emergencyExitPoll[_voteHash].voted(_voter);
  }

  /**
   * @dev See `CoreGovernance-_proposeProposal`.
   *
   * Requirements:
   * - The method caller is governor.
   *
   */
  function propose(
    uint256 _chainId,
    uint256 _expiryTimestamp,
    address[] calldata _targets,
    uint256[] calldata _values,
    bytes[] calldata _calldatas,
    uint256[] calldata _gasAmounts
  ) external onlyGovernor {
    _proposeProposal(_chainId, _expiryTimestamp, _targets, _values, _calldatas, _gasAmounts, msg.sender);
  }

  /**
   * @dev See `GovernanceProposal-_proposeProposalStructAndCastVotes`.
   *
   * Requirements:
   * - The method caller is governor.
   * - The proposal is for the current network.
   *
   */
  function proposeProposalStructAndCastVotes(
    Proposal.ProposalDetail calldata _proposal,
    Ballot.VoteType[] calldata _supports,
    Signature[] calldata _signatures
  ) external onlyGovernor {
    _proposeProposalStructAndCastVotes(_proposal, _supports, _signatures, DOMAIN_SEPARATOR, msg.sender);
  }

  /**
   * @dev Proposes and casts vote for a proposal on the current network.
   *
   * Requirements:
   * - The method caller is governor.
   * - The proposal is for the current network.
   *
   */
  function proposeProposalForCurrentNetwork(
    uint256 _expiryTimestamp,
    address[] calldata _targets,
    uint256[] calldata _values,
    bytes[] calldata _calldatas,
    uint256[] calldata _gasAmounts,
    Ballot.VoteType _support
  ) external onlyGovernor {
    address _voter = msg.sender;
    Proposal.ProposalDetail memory _proposal = _proposeProposal(
      block.chainid,
      _expiryTimestamp,
      _targets,
      _values,
      _calldatas,
      _gasAmounts,
      _voter
    );
    _castProposalVoteForCurrentNetwork(_voter, _proposal, _support);
  }

  /**
   * @dev Casts vote for a proposal on the current network.
   *
   * Requirements:
   * - The method caller is governor.
   *
   */
  function castProposalVoteForCurrentNetwork(
    Proposal.ProposalDetail calldata _proposal,
    Ballot.VoteType _support
  ) external onlyGovernor {
    _castProposalVoteForCurrentNetwork(msg.sender, _proposal, _support);
  }

  /**
   * @dev See `GovernanceProposal-_castProposalBySignatures`.
   */
  function castProposalBySignatures(
    Proposal.ProposalDetail calldata _proposal,
    Ballot.VoteType[] calldata _supports,
    Signature[] calldata _signatures
  ) external {
    _castProposalBySignatures(_proposal, _supports, _signatures, DOMAIN_SEPARATOR);
  }

  /**
   * @dev See `CoreGovernance-_proposeGlobal`.
   *
   * Requirements:
   * - The method caller is governor.
   *
   */
  function proposeGlobal(
    uint256 _expiryTimestamp,
    GlobalProposal.TargetOption[] calldata _targetOptions,
    uint256[] calldata _values,
    bytes[] calldata _calldatas,
    uint256[] calldata _gasAmounts
  ) external onlyGovernor {
    _proposeGlobal(
      _expiryTimestamp,
      _targetOptions,
      _values,
      _calldatas,
      _gasAmounts,
      getContract(ContractType.RONIN_TRUSTED_ORGANIZATION),
      getContract(ContractType.BRIDGE),
      msg.sender
    );
  }

  /**
   * @dev See `GovernanceProposal-_proposeGlobalProposalStructAndCastVotes`.
   *
   * Requirements:
   * - The method caller is governor.
   *
   */
  function proposeGlobalProposalStructAndCastVotes(
    GlobalProposal.GlobalProposalDetail calldata _globalProposal,
    Ballot.VoteType[] calldata _supports,
    Signature[] calldata _signatures
  ) external onlyGovernor {
    _proposeGlobalProposalStructAndCastVotes(
      _globalProposal,
      _supports,
      _signatures,
      DOMAIN_SEPARATOR,
      getContract(ContractType.RONIN_TRUSTED_ORGANIZATION),
      getContract(ContractType.BRIDGE),
      msg.sender
    );
  }

  /**
   * @dev See `GovernanceProposal-_castGlobalProposalBySignatures`.
   */
  function castGlobalProposalBySignatures(
    GlobalProposal.GlobalProposalDetail calldata _globalProposal,
    Ballot.VoteType[] calldata _supports,
    Signature[] calldata _signatures
  ) external {
    _castGlobalProposalBySignatures(
      _globalProposal,
      _supports,
      _signatures,
      DOMAIN_SEPARATOR,
      getContract(ContractType.RONIN_TRUSTED_ORGANIZATION),
      getContract(ContractType.BRIDGE)
    );
  }

  /**
   * @dev Deletes the expired proposal by its chainId and nonce, without creating a new proposal.
   *
   * Requirements:
   * - The proposal is already created.
   *
   */
  function deleteExpired(uint256 _chainId, uint256 _round) external {
    ProposalVote storage _vote = vote[_chainId][_round];
    if (_vote.hash == 0) revert ErrQueryForEmptyVote();

    _tryDeleteExpiredVotingRound(_vote);
  }

  /**
   * @inheritdoc IRoninGovernanceAdmin
   */
  function createEmergencyExitPoll(
    address _consensusAddr,
    address _recipientAfterUnlockedFund,
    uint256 _requestedAt,
    uint256 _expiredAt
  ) external onlyContract(ContractType.VALIDATOR) {
    bytes32 _hash = EmergencyExitBallot.hash(_consensusAddr, _recipientAfterUnlockedFund, _requestedAt, _expiredAt);
    IsolatedGovernance.Vote storage _v = _emergencyExitPoll[_hash];
    _v.createdAt = block.timestamp;
    _v.expiredAt = _expiredAt;
    emit EmergencyExitPollCreated(_hash, _consensusAddr, _recipientAfterUnlockedFund, _requestedAt, _expiredAt);
  }

  /**
   * @dev Votes for an emergency exit. Executes to unlock fund for the emergency exit's requester.
   *
   * Requirements:
   * - The voter is governor.
   * - The voting is existent.
   * - The voting is not expired yet.
   *
   */
  function voteEmergencyExit(
    bytes32 _voteHash,
    address _consensusAddr,
    address _recipientAfterUnlockedFund,
    uint256 _requestedAt,
    uint256 _expiredAt
  ) external onlyGovernor {
    address _voter = msg.sender;
    bytes32 _hash = EmergencyExitBallot.hash(_consensusAddr, _recipientAfterUnlockedFund, _requestedAt, _expiredAt);
    if (_voteHash != _hash) revert ErrInvalidVoteHash();

    IsolatedGovernance.Vote storage _v = _emergencyExitPoll[_hash];
    if (_v.createdAt == 0) revert ErrQueryForNonExistentVote();
    if (_v.status == VoteStatus.Expired) revert ErrQueryForExpiredVote();

    _v.castVote(_voter, _hash);
    emit EmergencyExitPollVoted(_hash, _voter);

    address[] memory _voters = _v.filterByHash(_hash);
    VoteStatus _stt = _v.syncVoteStatus(_getMinimumVoteWeight(), _sumGovernorWeights(_voters), _hash);
    if (_stt == VoteStatus.Approved) {
      _execReleaseLockedFundForEmergencyExitRequest(_consensusAddr, _recipientAfterUnlockedFund);
      emit EmergencyExitPollApproved(_hash);
      _v.status = VoteStatus.Executed;
    } else if (_stt == VoteStatus.Expired) {
      emit EmergencyExitPollExpired(_hash);
    }
  }

  /**
   * @inheritdoc GovernanceProposal
   */
  function _getWeight(address _governor) internal view virtual override returns (uint256) {
    bytes4 _selector = IRoninTrustedOrganization.getGovernorWeight.selector;
    (bool _success, bytes memory _returndata) = getContract(ContractType.RONIN_TRUSTED_ORGANIZATION).staticcall(
      abi.encodeWithSelector(
        // TransparentUpgradeableProxyV2.functionDelegateCall.selector,
        0x4bb5274a,
        abi.encodeWithSelector(_selector, _governor)
      )
    );
    _success.handleRevert(_selector, _returndata);
    return abi.decode(_returndata, (uint256));
  }

  /**
   * @dev Returns the total weight of a list address of governors.
   */
  function _sumGovernorWeights(address[] memory _governors) internal view virtual returns (uint256) {
    bytes4 _selector = IRoninTrustedOrganization.sumGovernorWeights.selector;
    (bool _success, bytes memory _returndata) = getContract(ContractType.RONIN_TRUSTED_ORGANIZATION).staticcall(
      abi.encodeWithSelector(
        // TransparentUpgradeableProxyV2.functionDelegateCall.selector,
        0x4bb5274a,
        abi.encodeWithSelector(_selector, _governors)
      )
    );

    _success.handleRevert(_selector, _returndata);
    return abi.decode(_returndata, (uint256));
  }

  /**
   * @dev Trigger function from validator contract to unlock fund for emeregency exit request.
   */
  function _execReleaseLockedFundForEmergencyExitRequest(
    address _consensusAddr,
    address _recipientAfterUnlockedFund
  ) internal virtual {
    bytes4 _selector = IEmergencyExit.execReleaseLockedFundForEmergencyExitRequest.selector;
    (bool _success, bytes memory _returndata) = getContract(ContractType.VALIDATOR).call(
      abi.encodeWithSelector(
        // TransparentUpgradeableProxyV2.functionDelegateCall.selector,
        0x4bb5274a,
        abi.encodeWithSelector(_selector, _consensusAddr, _recipientAfterUnlockedFund)
      )
    );
    _success.handleRevert(_selector, _returndata);
  }

  /**
   * @dev See `CoreGovernance-_getChainType`.
   */
  function _getChainType() internal pure override returns (ChainType) {
    return ChainType.RoninChain;
  }

  /**
   * @dev See `castProposalVoteForCurrentNetwork`.
   */
  function _castProposalVoteForCurrentNetwork(
    address _voter,
    Proposal.ProposalDetail memory _proposal,
    Ballot.VoteType _support
  ) internal {
    if (_proposal.chainId != block.chainid) revert ErrInvalidChainId(msg.sig, _proposal.chainId, block.chainid);

    bytes32 proposalHash = _proposal.hash();
    if (vote[_proposal.chainId][_proposal.nonce].hash != proposalHash)
      revert ErrInvalidProposal(proposalHash, vote[_proposal.chainId][_proposal.nonce].hash);

    uint256 _minimumForVoteWeight = _getMinimumVoteWeight();
    uint256 _minimumAgainstVoteWeight = _getTotalWeights() - _minimumForVoteWeight + 1;
    Signature memory _emptySignature;
    _castVote(
      _proposal,
      _support,
      _minimumForVoteWeight,
      _minimumAgainstVoteWeight,
      _voter,
      _emptySignature,
      _getWeight(_voter)
    );
  }
}
