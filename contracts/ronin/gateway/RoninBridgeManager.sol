// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { BridgeManager } from "../../extensions/bridge-operator-governance/BridgeManager.sol";
import { BOsGovernanceProposal } from "../../extensions/bridge-operator-governance/BOsGovernanceProposal.sol";
import { VoteStatusConsumer } from "../../interfaces/consumers/VoteStatusConsumer.sol";
import { IsolatedGovernance } from "../../libraries/IsolatedGovernance.sol";
import { BridgeOperatorsBallot } from "../../libraries/BridgeOperatorsBallot.sol";

contract RoninBridgeManager is BridgeManager, BOsGovernanceProposal {
  using IsolatedGovernance for IsolatedGovernance.Vote;

  constructor(
    uint256 num,
    uint256 denom,
    uint256 roninChainId,
    address admin,
    uint256[] memory voteWeights,
    address[] memory governors,
    address[] memory bridgeOperators
  ) payable BridgeManager(num, denom, roninChainId, admin, voteWeights, governors, bridgeOperators) {}

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

  function _sumBridgeVoterWeights(address[] memory _bridgeVoters) internal view override returns (uint256) {
    return getSumBridgeVoterWeights(_bridgeVoters);
  }

  function _isBridgeVoter(address addr) internal view override returns (bool) {
    return _getGovernorToBridgeOperatorInfo()[addr].voteWeight != 0;
  }
}
