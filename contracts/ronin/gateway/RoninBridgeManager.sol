// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ContractType, RoleAccess, ErrUnauthorized, BridgeManager } from "../../extensions/bridge-operator-governance/BridgeManager.sol";
import { Ballot, GlobalProposal, Proposal, GovernanceProposal } from "../../extensions/sequential-governance/governance-proposal/GovernanceProposal.sol";
import { CoreGovernance, GlobalCoreGovernance, GlobalGovernanceProposal } from "../../extensions/sequential-governance/governance-proposal/GlobalGovernanceProposal.sol";
import { VoteStatusConsumer } from "../../interfaces/consumers/VoteStatusConsumer.sol";
import { ErrQueryForEmptyVote } from "../../utils/CommonErrors.sol";

contract RoninBridgeManager is BridgeManager, GovernanceProposal, GlobalGovernanceProposal {
  constructor(
    uint256 num,
    uint256 denom,
    uint256 roninChainId,
    uint256 expiryDuration,
    address bridgeContract,
    address[] memory callbackRegisters,
    address[] memory bridgeOperators,
    address[] memory governors,
    uint96[] memory voteWeights,
    GlobalProposal.TargetOption[] memory targetOptions,
    address[] memory targets
  )
    payable
    CoreGovernance(expiryDuration)
    GlobalCoreGovernance(targetOptions, targets)
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
    uint256 expiryTimestamp,
    address[] calldata targets,
    uint256[] calldata values,
    bytes[] calldata calldatas,
    uint256[] calldata gasAmounts,
    Ballot.VoteType support
  ) external onlyGovernor {
    address _voter = msg.sender;
    Proposal.ProposalDetail memory _proposal = _proposeProposal({
      chainId: block.chainid,
      expiryTimestamp: expiryTimestamp,
      targets: targets,
      values: values,
      calldatas: calldatas,
      gasAmounts: gasAmounts,
      creator: _voter
    });
    _castProposalVoteForCurrentNetwork(_voter, _proposal, support);
  }

  /**
   * @dev Casts vote for a proposal on the current network.
   *
   * Requirements:
   * - The method caller is governor.
   *
   */
  function castProposalVoteForCurrentNetwork(
    Proposal.ProposalDetail calldata proposal,
    Ballot.VoteType support
  ) external onlyGovernor {
    _castProposalVoteForCurrentNetwork(msg.sender, proposal, support);
  }

  /**
   * @dev See `GovernanceProposal-_castProposalBySignatures`.
   */
  function castProposalBySignatures(
    Proposal.ProposalDetail calldata proposal,
    Ballot.VoteType[] calldata supports_,
    Signature[] calldata signatures
  ) external {
    _castProposalBySignatures(proposal, supports_, signatures, DOMAIN_SEPARATOR);
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
    uint256 expiryTimestamp,
    GlobalProposal.TargetOption[] calldata targetOptions,
    uint256[] calldata values,
    bytes[] calldata calldatas,
    uint256[] calldata gasAmounts
  ) external onlyGovernor {
    _proposeGlobal({
      expiryTimestamp: expiryTimestamp,
      targetOptions: targetOptions,
      values: values,
      calldatas: calldatas,
      gasAmounts: gasAmounts,
      creator: msg.sender
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
    GlobalProposal.GlobalProposalDetail calldata globalProposal,
    Ballot.VoteType[] calldata supports_,
    Signature[] calldata signatures
  ) external onlyGovernor {
    _proposeGlobalProposalStructAndCastVotes({
      globalProposal: globalProposal,
      supports_: supports_,
      signatures: signatures,
      domainSeparator: DOMAIN_SEPARATOR,
      creator: msg.sender
    });
  }

  /**
   * @dev See `GovernanceProposal-_castGlobalProposalBySignatures`.
   */
  function castGlobalProposalBySignatures(
    GlobalProposal.GlobalProposalDetail calldata globalProposal,
    Ballot.VoteType[] calldata supports_,
    Signature[] calldata signatures
  ) external {
    _castGlobalProposalBySignatures({
      globalProposal: globalProposal,
      supports_: supports_,
      signatures: signatures,
      domainSeparator: DOMAIN_SEPARATOR
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
  function _getTotalWeight() internal view virtual override returns (uint256) {
    return getTotalWeight();
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
