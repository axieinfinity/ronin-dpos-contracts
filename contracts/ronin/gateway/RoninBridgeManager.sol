// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ContractType, RoleAccess, ErrUnauthorized, BridgeManager } from "../../extensions/bridge-operator-governance/BridgeManager.sol";
import "../../extensions/sequential-governance/governance-proposal/GlobalGovernanceProposal.sol";
import { IsolatedGovernance } from "../../libraries/IsolatedGovernance.sol";
import { BridgeOperatorsBallot } from "../../libraries/BridgeOperatorsBallot.sol";
import { VoteStatusConsumer } from "../../interfaces/consumers/VoteStatusConsumer.sol";

contract RoninBridgeManager is BridgeManager, GlobalGovernanceProposal {
  using IsolatedGovernance for IsolatedGovernance.Vote;

  modifier onlyGovernor() {
    _requireGovernor();
    _;
  }

  constructor(
    uint256 num,
    uint256 denom,
    uint256 roninChainId,
    uint256 expiryDuration,
    address bridgeContract,
    address[] memory callbackRegisters,
    address[] memory bridgeOperators,
    address[] memory governors,
    uint256[] memory voteWeights
  )
    payable
    CoreGovernance(expiryDuration)
    BridgeManager(num, denom, roninChainId, bridgeContract, callbackRegisters, bridgeOperators, governors, voteWeights)
  {}

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
    _castGlobalProposalBySignatures(
      _globalProposal,
      _supports,
      _signatures,
      DOMAIN_SEPARATOR,
      address(this),
      getContract(ContractType.BRIDGE)
    );
  }

  /**
   * @dev Returns the voted signatures for the proposals.
   *
   * Note: The signatures can be empty in case the proposal is voted on the current network.
   *
   */
  function getProposalSignatures(
    uint256 _round
  )
    external
    view
    returns (address[] memory _voters, Ballot.VoteType[] memory _supports, Signature[] memory _signatures)
  {
    uint256 _chainId = 0;

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
  function proposalVoted(uint256 _round, address _voter) external view returns (bool) {
    //    uint256 _round = _createVotingRound(0);
    //    _saveVotingRound(vote[0][_round], _proposalHash, _globalProposal.expiryTimestamp);
    return _voted(vote[0][_round], _voter);
  }

  /**
   * @dev Returns the expiry duration for a new proposal.
   */
  function getProposalExpiryDuration() external view returns (uint256) {
    return _getProposalExpiryDuration();
  }

  function _requireGovernor() internal view {
    if (_getWeight(msg.sender) == 0) revert ErrUnauthorized(msg.sig, RoleAccess.GOVERNOR);
  }

  function _getChainType() internal pure override returns (ChainType) {
    return ChainType.RoninChain;
  }

  function _getTotalWeights() internal view virtual override returns (uint256) {
    return getTotalWeights();
  }

  function _getMinimumVoteWeight() internal view virtual override returns (uint256) {
    return minimumVoteWeight();
  }

  function _getWeight(address _governor) internal view virtual override returns (uint256) {
    BridgeOperatorInfo memory bridgeOperatorInfo = _getGovernorToBridgeOperatorInfo()[_governor];
    return bridgeOperatorInfo.voteWeight;
  }
}
