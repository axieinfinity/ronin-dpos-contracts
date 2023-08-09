// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ContractType, RoleAccess, ErrUnauthorized, BridgeManager } from "../../extensions/bridge-operator-governance/BridgeManager.sol";
import { Ballot, GlobalProposal, Proposal, GovernanceProposal } from "../../extensions/sequential-governance/governance-proposal/GovernanceProposal.sol";
import { CoreGovernance, GlobalGovernanceProposal } from "../../extensions/sequential-governance/governance-proposal/GlobalGovernanceProposal.sol";
import { IsolatedGovernance } from "../../libraries/IsolatedGovernance.sol";
import { BridgeOperatorsBallot } from "../../libraries/BridgeOperatorsBallot.sol";
import { VoteStatusConsumer } from "../../interfaces/consumers/VoteStatusConsumer.sol";
import { ErrQueryForEmptyVote } from "../../utils/CommonErrors.sol";

contract RoninBridgeManager is BridgeManager, GovernanceProposal, GlobalGovernanceProposal {
  using IsolatedGovernance for IsolatedGovernance.Vote;

  constructor(
    uint256 num,
    uint256 denom,
    uint256 roninChainId,
    uint256 expiryDuration,
    address bridgeContract,
    address[] memory callbackRegisters,
    address[] memory bridgeOperators,
    address[] memory governors,
    uint96[] memory voteWeights
  )
    payable
    CoreGovernance(expiryDuration)
    BridgeManager(num, denom, roninChainId, bridgeContract, callbackRegisters, bridgeOperators, governors, voteWeights)
  {}

  /**
   * CURRENT NETWORK
   */

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
    Proposal.ProposalDetail memory _proposal = _proposeProposal({
      _chainId: block.chainid,
      _expiryTimestamp: _expiryTimestamp,
      _targets: _targets,
      _values: _values,
      _calldatas: _calldatas,
      _gasAmounts: _gasAmounts,
      _creator: _voter
    });
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
   * GLOBAL NETWORK
   */

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
    _proposeGlobal({
      _expiryTimestamp: _expiryTimestamp,
      _targetOptions: _targetOptions,
      _values: _values,
      _calldatas: _calldatas,
      _gasAmounts: _gasAmounts,
      _bridgeManagerContract: address(this),
      _gatewayContract: getContract(ContractType.BRIDGE),
      _creator: msg.sender
    });
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
    _proposeGlobalProposalStructAndCastVotes({
      _globalProposal: _globalProposal,
      _supports: _supports,
      _signatures: _signatures,
      _domainSeparator: DOMAIN_SEPARATOR,
      _bridgeManagerContract: address(this),
      _gatewayContract: getContract(ContractType.BRIDGE),
      _creator: msg.sender
    });
  }

  /**
   * @dev See `GovernanceProposal-_castGlobalProposalBySignatures`.
   */
  function castGlobalProposalBySignatures(
    GlobalProposal.GlobalProposalDetail calldata _globalProposal,
    Ballot.VoteType[] calldata _supports,
    Signature[] calldata _signatures
  ) external {
    _castGlobalProposalBySignatures({
      _globalProposal: _globalProposal,
      _supports: _supports,
      _signatures: _signatures,
      _domainSeparator: DOMAIN_SEPARATOR,
      _bridgeManagerContract: address(this),
      _gatewayContract: getContract(ContractType.BRIDGE)
    });
  }

  /**
   * COMMON METHODS
   */

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
   * @dev Returns the expiry duration for a new proposal.
   */
  function getProposalExpiryDuration() external view returns (uint256) {
    return _getProposalExpiryDuration();
  }

  /**
   * @dev Internal function to get the chain type of the contract.
   * @return The chain type, indicating the type of the chain the contract operates on (e.g., RoninChain).
   */
  function _getChainType() internal pure override returns (ChainType) {
    return ChainType.RoninChain;
  }

  /**
   * @dev Internal function to get the total weights of all governors.
   * @return The total weights of all governors combined.
   */
  function _getTotalWeights() internal view virtual override returns (uint256) {
    return getTotalWeights();
  }

  /**
   * @dev Internal function to get the minimum vote weight required for governance actions.
   * @return The minimum vote weight required for governance actions.
   */
  function _getMinimumVoteWeight() internal view virtual override returns (uint256) {
    return minimumVoteWeight();
  }

  /**
   * @dev Internal function to get the vote weight of a specific governor.
   * @param _governor The address of the governor to get the vote weight for.
   * @return The vote weight of the specified governor.
   */
  function _getWeight(address _governor) internal view virtual override returns (uint256) {
    return _getGovernorWeight(_governor);
  }
}
