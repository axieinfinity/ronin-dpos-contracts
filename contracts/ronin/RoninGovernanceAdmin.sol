// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../extensions/sequential-governance/governance-proposal/GovernanceProposal.sol";
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
    uint256 _expiryDuration
  ) CoreGovernance(_expiryDuration) GovernanceAdmin(_roninChainId, _roninTrustedOrganizationContract) {
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
    VoteStatus _stt = _v.syncVoteStatus(_getMinimumVoteWeight(), _sumGovernorWeight(_voters), _hash);
    if (_stt == VoteStatus.Approved) {
      _execReleaseLockedFundForEmergencyExitRequest(_consensusAddr, _recipientAfterUnlockedFund);
      emit EmergencyExitPollApproved(_hash);
      _v.status = VoteStatus.Executed;
    } else if (_stt == VoteStatus.Expired) {
      emit EmergencyExitPollExpired(_hash);
    }
  }

  /**
   * @dev Returns weight of a govenor.
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
  function _sumGovernorWeight(address[] memory _governors) internal view virtual returns (uint256) {
    bytes4 _selector = IRoninTrustedOrganization.sumGovernorWeight.selector;
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
}
