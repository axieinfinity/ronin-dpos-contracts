// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AccessControlEnumerable } from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import { CoreGovernance } from "../extensions/sequential-governance/CoreGovernance.sol";
import { GovernanceRelay } from "../extensions/sequential-governance/GovernanceRelay.sol";
import { BOsGovernanceRelay } from "../extensions/bridge-operator-governance/BOsGovernanceRelay.sol";
import { ContractType, BridgeManager } from "../extensions/bridge-operator-governance/BridgeManager.sol";
import { ChainTypeConsumer } from "../interfaces/consumers/ChainTypeConsumer.sol";
import { Ballot } from "../libraries/Ballot.sol";
import { GlobalProposal } from "../libraries/GlobalProposal.sol";

contract MainchainBridgeManager is
  ChainTypeConsumer,
  AccessControlEnumerable,
  BridgeManager,
  GovernanceRelay,
  BOsGovernanceRelay
{
  bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

  constructor(
    uint256 num,
    uint256 denom,
    uint256 roninChainId,
    uint256 expiryDuration,
    address bridgeContract,
    address[] memory relayers,
    address[] memory bridgeOperators,
    address[] memory governors,
    uint256[] memory voteWeights
  )
    payable
    GovernanceRelay(expiryDuration)
    BridgeManager(num, denom, roninChainId, bridgeContract, bridgeOperators, governors, voteWeights)
  {
    uint256 length = relayers.length;
    bytes32 relayerRole = RELAYER_ROLE;
    for (uint256 i; i < length; ) {
      _grantRole(relayerRole, relayers[i]);

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @dev See `GovernanceRelay-_relayGlobalProposal`.
   *
   * Requirements:
   * - The method caller is relayer.
   *
   */
  function relayGlobalProposal(
    GlobalProposal.GlobalProposalDetail calldata _globalProposal,
    Ballot.VoteType[] calldata _supports,
    Signature[] calldata _signatures
  ) external onlyRole(RELAYER_ROLE) {
    _relayGlobalProposal({
      _globalProposal: _globalProposal,
      _supports: _supports,
      _signatures: _signatures,
      _domainSeparator: DOMAIN_SEPARATOR,
      _bridgeManager: address(this),
      _gatewayContract: getContract(ContractType.BRIDGE),
      _creator: msg.sender
    });
  }

  /**
   * @dev Returns whether the voter `_voter` casted vote for bridge operators at a specific period.
   */
  function bridgeOperatorsRelayed(uint256 _period, uint256 _epoch) external view returns (bool) {
    return _vote[_period][_epoch].status != VoteStatus.Pending;
  }

  function _getMinimumVoteWeight() internal view override returns (uint256) {
    return (_num * _totalWeight + _denom - 1) / _denom;
  }

  /**
   * @dev Returns the expiry duration for a new proposal.
   */
  function getProposalExpiryDuration() external view returns (uint256) {
    return _getProposalExpiryDuration();
  }

  /**
   * @inheritdoc CoreGovernance
   */
  function _getWeight(address governor) internal view override returns (uint256) {}

  /**
   * @inheritdoc BOsGovernanceRelay
   */
  function _sumBridgeVoterWeights(address[] memory governors) internal view override returns (uint256) {
    return getSumBridgeVoterWeights(governors);
  }

  function _getTotalWeights() internal view override returns (uint256) {
    return _totalWeight;
  }

  function _sumWeights(address[] memory governors) internal view override returns (uint256) {
    return _sumBridgeVoterWeights(governors);
  }

  function _getChainType() internal pure override returns (ChainType) {
    return ChainType.Mainchain;
  }
}
