// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AccessControlEnumerable } from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import { CoreGovernance } from "../extensions/sequential-governance/CoreGovernance.sol";
import { GlobalGovernanceRelay } from "../extensions/sequential-governance/governance-relay/GlobalGovernanceRelay.sol";
import { ContractType, BridgeManager } from "../extensions/bridge-operator-governance/BridgeManager.sol";
import { ChainTypeConsumer } from "../interfaces/consumers/ChainTypeConsumer.sol";
import { Ballot } from "../libraries/Ballot.sol";
import { GlobalProposal } from "../libraries/GlobalProposal.sol";

contract MainchainBridgeManager is ChainTypeConsumer, AccessControlEnumerable, BridgeManager, GlobalGovernanceRelay {
  constructor(
    uint256 num,
    uint256 denom,
    uint256 roninChainId,
    address bridgeContract,
    address[] memory callbackRegisters,
    address[] memory bridgeOperators,
    address[] memory governors,
    uint256[] memory voteWeights
  )
    payable
    CoreGovernance(type(uint256).max - 1)
    BridgeManager(num, denom, roninChainId, bridgeContract, callbackRegisters, bridgeOperators, governors, voteWeights)
  {}

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
  ) external {
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

  function _getMinimumVoteWeight() internal view override returns (uint256) {
    return minimumVoteWeight();
  }

  /**
   * @dev Returns the expiry duration for a new proposal.
   */
  function getProposalExpiryDuration() external view returns (uint256) {
    return _getProposalExpiryDuration();
  }

  function _getTotalWeights() internal view override returns (uint256) {
    return getTotalWeights();
  }

  function _sumWeights(address[] memory governors) internal view override returns (uint256) {
    return getSumBridgeVoterWeights(governors);
  }

  function _getChainType() internal pure override returns (ChainType) {
    return ChainType.Mainchain;
  }
}
