// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ContractType, RoleAccess, ErrUnauthorized, BridgeManager } from "../../extensions/bridge-operator-governance/BridgeManager.sol";
import { Ballot, GlobalProposal, BOsGlobalProposal } from "../../extensions/bridge-operator-governance/BOsGlobalProposal.sol";
import { BOsGovernanceProposal } from "../../extensions/bridge-operator-governance/BOsGovernanceProposal.sol";
import { IsolatedGovernance } from "../../libraries/IsolatedGovernance.sol";
import { BridgeOperatorsBallot } from "../../libraries/BridgeOperatorsBallot.sol";
import { VoteStatusConsumer } from "../../interfaces/consumers/VoteStatusConsumer.sol";

contract RoninBridgeManager is BridgeManager, BOsGlobalProposal, BOsGovernanceProposal {
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
    address[] memory bridgeOperators,
    address[] memory governors,
    uint256[] memory voteWeights
  )
    payable
    BOsGlobalProposal(expiryDuration)
    BridgeManager(num, denom, roninChainId, bridgeContract, bridgeOperators, governors, voteWeights)
  {}

  /**
   * @dev See `BOsGovernanceProposal-_castVotesBySignatures`.
   */
  function voteBridgeOperatorsBySignatures(
    BridgeOperatorsBallot.BridgeOperatorSet calldata _ballot,
    Signature[] calldata _signatures
  ) external {
    _castBOVotesBySignatures(_ballot, _signatures, minimumVoteWeight(), DOMAIN_SEPARATOR);
    IsolatedGovernance.Vote storage _v = _bridgeOperatorVote[_ballot.period][_ballot.epoch];
    if (_v.status == VoteStatusConsumer.VoteStatus.Approved) {
      _lastSyncedBridgeOperatorSetInfo = _ballot;
      emit BridgeOperatorsApproved(_ballot.period, _ballot.epoch, _ballot.operators);
      _v.status = VoteStatusConsumer.VoteStatus.Executed;
    }
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
   * @dev Returns the voted signatures for bridge operators at a specific period.
   */
  function getBridgeOperatorVotingSignatures(
    uint256 _period,
    uint256 _epoch
  ) external view returns (address[] memory _voters, Signature[] memory _signatures) {
    mapping(address => Signature) storage _sigMap = _bridgeVoterSig[_period][_epoch];
    _voters = _bridgeOperatorVote[_period][_epoch].voters;
    _signatures = new Signature[](_voters.length);
    for (uint _i; _i < _voters.length; ) {
      _signatures[_i] = _sigMap[_voters[_i]];

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @dev Returns whether the voter `_voter` casted vote for bridge operators at a specific period.
   */
  function bridgeOperatorsVoted(uint256 _period, uint256 _epoch, address _voter) external view returns (bool) {
    return _bridgeOperatorVote[_period][_epoch].voted(_voter);
  }

  /**
   * @dev Returns the expiry duration for a new proposal.
   */
  function getProposalExpiryDuration() external view returns (uint256) {
    return _getProposalExpiryDuration();
  }

  function _sumBridgeVoterWeights(address[] memory _bridgeVoters) internal view override returns (uint256) {
    return getSumBridgeVoterWeights(_bridgeVoters);
  }

  function _requireGovernor() internal view {
    if (!_isBridgeVoter(msg.sender)) revert ErrUnauthorized(msg.sig, RoleAccess.GOVERNOR);
  }

  function _isBridgeVoter(address addr) internal view override returns (bool) {
    return _getGovernorToBridgeOperatorInfo()[addr].voteWeight != 0;
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
