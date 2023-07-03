// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AccessControlEnumerable } from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import { TransparentUpgradeableProxyV2 } from "../extensions/TransparentUpgradeableProxyV2.sol";
import { BOsGovernanceRelay } from "../extensions/bridge-operator-governance/BOsGovernanceRelay.sol";
import { BridgeAdminOperator } from "../extensions/bridge-operator-governance/BridgeAdminOperator.sol";
import { BridgeOperatorsBallot } from "../libraries/BridgeOperatorsBallot.sol";

contract MainchainBridgeAdmin is AccessControlEnumerable, BridgeAdminOperator, BOsGovernanceRelay {
  bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

  constructor(
    uint256 num,
    uint256 denom,
    uint256 roninChainId,
    address admin,
    address bridgeContract,
    address[] memory relayers
  ) payable BridgeAdminOperator(num, denom, roninChainId, admin, bridgeContract) {
    _grantRole(DEFAULT_ADMIN_ROLE, admin);
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
   * @dev Returns whether the voter `_voter` casted vote for bridge operators at a specific period.
   */
  function bridgeOperatorsRelayed(uint256 _period, uint256 _epoch) external view returns (bool) {
    return _vote[_period][_epoch].status != VoteStatus.Pending;
  }

  /**
   * @dev See `BOsGovernanceRelay-_relayVotesBySignatures`.
   *
   * Requirements:
   * - The method caller is relayer.
   *
   */
  function relayBridgeOperators(
    BridgeOperatorsBallot.BridgeOperatorSet calldata _ballot,
    Signature[] calldata _signatures
  ) external onlyRole(RELAYER_ROLE) {
    _relayVotesBySignatures(_ballot, _signatures, _getMinimumVoteWeight(), DOMAIN_SEPARATOR);

    address[] memory bridgeOperators = getBridgeOperators();
    _removeBridgeOperators(bridgeOperators);
    _addBridgeOperators(_ballot.voteWeights, _ballot.governors, _ballot.operators);
  }

  function _getMinimumVoteWeight() internal view returns (uint256) {
    return (_num * _totalWeight + _denom - 1) / _denom;
  }

  /**
   * @inheritdoc BOsGovernanceRelay
   */
  function _sumBridgeVoterWeights(address[] memory _bridgeVoters) internal view override returns (uint256) {
    return getSumBridgeVoterWeights(_bridgeVoters);
  }
}
