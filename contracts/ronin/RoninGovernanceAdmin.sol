// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../extensions/isolated-governance/bridge-operator-governance/BOsGovernanceProposal.sol";
import "../extensions/sequential-governance/GovernanceProposal.sol";
import "../extensions/collections/HasValidatorContract.sol";
import "../extensions/GovernanceAdmin.sol";
import "../libraries/EmergencyExitBallot.sol";
import "../interfaces/IBridge.sol";
import "../interfaces/IRoninGovernanceAdmin.sol";

contract RoninGovernanceAdmin is
  IRoninGovernanceAdmin,
  GovernanceAdmin,
  GovernanceProposal,
  BOsGovernanceProposal,
  HasValidatorContract
{
  /// @dev Mapping from request hash => bridge operators vote
  mapping(bytes32 => IsolatedVote) internal _emergecyVote;

  /// @dev Emitted when the bridge operators are approved.
  event BridgeOperatorsApproved(uint256 _period, uint256 _epoch, address[] _operators);

  modifier onlyGovernor() {
    require(_getWeight(msg.sender) > 0, "RoninGovernanceAdmin: sender is not governor");
    _;
  }

  constructor(
    address _roninTrustedOrganizationContract,
    address _bridgeContract,
    uint256 _proposalExpiryDuration
  ) GovernanceAdmin(_roninTrustedOrganizationContract, _bridgeContract, _proposalExpiryDuration) {}

  /**
   * @inheritdoc IHasValidatorContract
   */
  function setValidatorContract(address _addr) external override onlyAdmin {
    require(_addr.code.length > 0, "RoninGovernanceAdmin: set to non-contract");
    _setValidatorContract(_addr);
  }

  /**
   * @dev Returns the voted signatures for the proposals.
   *
   */
  function getProposalSignatures(uint256 _chainId, uint256 _round)
    external
    view
    returns (Ballot.VoteType[] memory _supports, Signature[] memory _signatures)
  {
    ProposalVote storage _vote = vote[_chainId][_round];

    uint256 _forLength = _vote.forVoteds.length;
    uint256 _againstLength = _vote.againstVoteds.length;
    uint256 _voterLength = _forLength + _againstLength;

    _supports = new Ballot.VoteType[](_voterLength);
    _signatures = new Signature[](_voterLength);
    for (uint256 _i; _i < _forLength; _i++) {
      _supports[_i] = Ballot.VoteType.For;
      _signatures[_i] = vote[_chainId][_round].sig[_vote.forVoteds[_i]];
    }
    for (uint256 _i; _i < _againstLength; _i++) {
      _supports[_i + _forLength] = Ballot.VoteType.Against;
      _signatures[_i + _forLength] = vote[_chainId][_round].sig[_vote.againstVoteds[_i]];
    }
  }

  /**
   * @dev Returns the voted signatures for bridge operators at a specific period.
   *
   * Note: Does not verify whether the voter casted vote for the proposal and the returned signature can be empty.
   * Please consider filtering for empty signatures after calling this function.
   *
   */
  function getBridgeOperatorVotingSignatures(
    uint256 _period,
    uint256 _epoch,
    address[] calldata _voters
  ) external view returns (Signature[] memory _signatures) {
    _signatures = new Signature[](_voters.length);
    for (uint256 _i; _i < _voters.length; _i++) {
      _signatures[_i] = _votingSig[_period][_epoch][_voters[_i]];
    }
  }

  /**
   * @dev Returns whether the voter `_voter` casted vote for the proposal.
   */
  function proposalVoted(
    uint256 _chainId,
    uint256 _round,
    address _voter
  ) external view returns (bool) {
    return _voted(vote[_chainId][_round], _voter);
  }

  /**
   * @dev Returns whether the voter `_voter` casted vote for bridge operators at a specific period.
   */
  function bridgeOperatorsVoted(
    uint256 _period,
    uint256 _epoch,
    address _voter
  ) external view returns (bool) {
    return _voted(_vote[_period][_epoch], _voter);
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
      roninTrustedOrganizationContract(),
      bridgeContract(),
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
      roninTrustedOrganizationContract(),
      bridgeContract(),
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
      roninTrustedOrganizationContract(),
      bridgeContract()
    );
  }

  /**
   * @dev See `CoreGovernance-_deleteExpiredProposal`
   */
  function deleteExpired(uint256 chainId, uint256 round) external {
    _deleteExpiredVotingRound(chainId, round);
  }

  /**
   * @dev See `BOsGovernanceProposal-_castVotesBySignatures`.
   */
  function voteBridgeOperatorsBySignatures(
    uint256 _period,
    uint256 _epoch,
    address[] calldata _operators,
    Signature[] calldata _signatures
  ) external {
    _castVotesBySignatures(_operators, _signatures, _period, _epoch, _getMinimumVoteWeight(), DOMAIN_SEPARATOR);
    IsolatedVote storage _v = _vote[_period][_epoch];
    if (_v.status == VoteStatus.Approved) {
      _lastSyncedPeriod = _period;
      _lastSyncedEpoch = _epoch;
      emit BridgeOperatorsApproved(_period, _epoch, _operators);
      _v.status = VoteStatus.Executed;
    }
  }

  /**
   * @inheritdoc IRoninGovernanceAdmin
   */
  function createEmergencyExitVote(
    address _consensusAddr,
    address _recipientAfterUnlockedFund,
    uint256 _requestedAt,
    uint256 _expiredAt
  ) external onlyValidatorContract {
    bytes32 _hash = EmergencyExitBallot.hash(_consensusAddr, _recipientAfterUnlockedFund, _requestedAt);
    IsolatedVote storage _v = _emergecyVote[_hash];
    _v.createdAt = block.timestamp;
    _v.expiredAt = _expiredAt;
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
    address _consensusAddr,
    address _recipientAfterUnlockedFund,
    uint256 _requestedAt
  ) external {
    address _voter = msg.sender;
    uint256 _weight = _getWeight(_voter);
    require(_weight > 0, "RoninGovernanceAdmin: sender is not governor");

    bytes32 _hash = EmergencyExitBallot.hash(_consensusAddr, _recipientAfterUnlockedFund, _requestedAt);
    IsolatedVote storage _v = _emergecyVote[_hash];
    require(_v.createdAt > 0, "RoninGovernanceAdmin: query for un-existent vote");
    require(_v.expiredAt > 0 && _v.expiredAt <= block.timestamp, "RoninGovernanceAdmin: query for expired vote");
    if (_castVote(_v, _voter, _weight, _getMinimumVoteWeight(), _hash) == VoteStatus.Approved) {
      _unlockFundForEmergencyExitRequest(_consensusAddr, _recipientAfterUnlockedFund);
      _v.status = VoteStatus.Executed;
    }
  }

  /**
   * @inheritdoc GovernanceProposal
   */
  function _getWeight(address _governor) internal view virtual override returns (uint256) {
    (bool _success, bytes memory _returndata) = roninTrustedOrganizationContract().staticcall(
      abi.encodeWithSelector(
        // TransparentUpgradeableProxyV2.functionDelegateCall.selector,
        0x4bb5274a,
        abi.encodeWithSelector(IRoninTrustedOrganization.getGovernorWeight.selector, _governor)
      )
    );
    require(_success, "GovernanceAdmin: proxy call `getGovernorWeight(address)` failed");
    return abi.decode(_returndata, (uint256));
  }

  /**
   * @inheritdoc BOsGovernanceProposal
   */
  function _getBridgeVoterWeight(address _governor) internal view virtual override returns (uint256) {
    (bool _success, bytes memory _returndata) = roninTrustedOrganizationContract().staticcall(
      abi.encodeWithSelector(
        // TransparentUpgradeableProxyV2.functionDelegateCall.selector,
        0x4bb5274a,
        abi.encodeWithSelector(IRoninTrustedOrganization.getBridgeVoterWeight.selector, _governor)
      )
    );
    require(_success, "GovernanceAdmin: proxy call `getBridgeVoterWeight(address)` failed");
    return abi.decode(_returndata, (uint256));
  }

  function _unlockFundForEmergencyExitRequest(address _consensusAddr, address _recipientAfterUnlockedFund)
    internal
    virtual
  {
    (bool _success, ) = validatorContract().call(
      abi.encodeWithSelector(
        // TransparentUpgradeableProxyV2.functionDelegateCall.selector,
        0x4bb5274a,
        abi.encodeWithSelector(
          _validatorContract.unlockFundForEmergencyExitRequest.selector,
          _consensusAddr,
          _recipientAfterUnlockedFund
        )
      )
    );
    require(_success, "GovernanceAdmin: proxy call `unlockFundForEmergencyExitRequest(address,address)` failed");
  }

  /**
   * @dev See {CoreGovernance-_getChainType}
   */
  function _getChainType() internal pure override returns (ChainType) {
    return ChainType.RoninChain;
  }
}
