// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { CoreGovernance } from "../extensions/sequential-governance/CoreGovernance.sol";
import { GlobalGovernanceRelay } from "../extensions/sequential-governance/governance-relay/GlobalGovernanceRelay.sol";
import { GovernanceRelay } from "../extensions/sequential-governance/governance-relay/GovernanceRelay.sol";
import { ContractType, BridgeManager } from "../extensions/bridge-operator-governance/BridgeManager.sol";
import { Ballot } from "../libraries/Ballot.sol";
import { Proposal } from "../libraries/Proposal.sol";
import { GlobalProposal } from "../libraries/GlobalProposal.sol";
import "../utils/CommonErrors.sol";

contract MainchainBridgeManager is BridgeManager, GovernanceRelay, GlobalGovernanceRelay {
  uint256 private constant DEFAULT_EXPIRY_DURATION = 1 << 255;

  constructor(
    uint256 num,
    uint256 denom,
    uint256 roninChainId,
    address bridgeContract,
    address[] memory callbackRegisters,
    address[] memory bridgeOperators,
    address[] memory governors,
    uint96[] memory voteWeights
  )
    payable
    CoreGovernance(DEFAULT_EXPIRY_DURATION)
    BridgeManager(num, denom, roninChainId, bridgeContract, callbackRegisters, bridgeOperators, governors, voteWeights)
  {}

  /**
   * @dev See `GovernanceRelay-_relayProposal`.
   *
   * Requirements:
   * - The method caller is governor.
   */
  function relayProposal(
    Proposal.ProposalDetail calldata _proposal,
    Ballot.VoteType[] calldata _supports,
    Signature[] calldata _signatures
  ) external onlyGovernor {
    _relayProposal(_proposal, _supports, _signatures, DOMAIN_SEPARATOR, msg.sender);
  }

  /**
   * @dev See `GovernanceRelay-_relayGlobalProposal`.
   *
   *  Requirements:
   * - The method caller is governor.
   */
  function relayGlobalProposal(
    GlobalProposal.GlobalProposalDetail calldata _globalProposal,
    Ballot.VoteType[] calldata _supports,
    Signature[] calldata _signatures
  ) external onlyGovernor {
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
   * @dev Internal function to retrieve the minimum vote weight required for governance actions.
   * @return minimumVoteWeight The minimum vote weight required for governance actions.
   */
  function _getMinimumVoteWeight() internal view override returns (uint256) {
    return minimumVoteWeight();
  }

  /**
   * @dev Returns the expiry duration for a new proposal.
   */
  function getProposalExpiryDuration() external view returns (uint256) {
    return _getProposalExpiryDuration();
  }

  /**
   * @dev Internal function to retrieve the total weights of all governors.
   * @return totalWeights The total weights of all governors combined.
   */
  function _getTotalWeights() internal view override returns (uint256) {
    return getTotalWeights();
  }

  /**
   * @dev Internal function to calculate the sum of weights for a given array of governors.
   * @param governors An array containing the addresses of governors to calculate the sum of weights.
   * @return sumWeights The sum of weights for the provided governors.
   */
  function _sumWeights(address[] memory governors) internal view override returns (uint256) {
    return _sumGovernorsWeight(governors);
  }

  /**
   * @dev Internal function to retrieve the chain type of the contract.
   * @return chainType The chain type, indicating the type of the chain the contract operates on (e.g., Mainchain).
   */
  function _getChainType() internal pure override returns (ChainType) {
    return ChainType.Mainchain;
  }

  /**
   * @dev Internal function to retrieve the vote weight of a specific governor.
   * @param _governor The address of the governor to get the vote weight for.
   * @return voteWeight The vote weight of the specified governor.
   */
  function _getWeight(address _governor) internal view virtual override returns (uint256) {
    return _getGovernorToBridgeOperatorInfo()[_governor].voteWeight;
  }
}
