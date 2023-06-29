// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { EnumerableSet, BridgeAdminOperator } from "./BridgeAdminOperator.sol";
import { BOsGovernanceProposal } from "../../extensions/bridge-operator-governance/BOsGovernanceProposal.sol";
import { ErrorHandler } from "../../libraries/ErrorHandler.sol";
import { IsolatedGovernance } from "../../libraries/IsolatedGovernance.sol";
import { BridgeOperatorsBallot } from "../../libraries/BridgeOperatorsBallot.sol";
import { IQuorum } from "../../interfaces/IQuorum.sol";
import { VoteStatusConsumer } from "../../interfaces/consumers/VoteStatusConsumer.sol";
import { ErrInvalidThreshold } from "../../utils/CommonErrors.sol";

contract BridgeAdmin is IQuorum, BridgeAdminOperator, BOsGovernanceProposal {
  using ErrorHandler for bool;
  using EnumerableSet for EnumerableSet.AddressSet;
  using IsolatedGovernance for IsolatedGovernance.Vote;

  bytes32 DOMAIN_SEPARATOR;

  uint256 internal _num;
  uint256 internal _denom;

  uint256 internal _nonce;

  constructor(
    uint256 num,
    uint256 denom,
    uint256 roninChainId,
    address bridgeContract,
    uint256[] memory voteWeights,
    address[] memory governors,
    address[] memory bridgeOperators
  ) payable BridgeAdminOperator(bridgeContract, voteWeights, governors, bridgeOperators) {
    _nonce = 1;
    _num = num;
    _denom = denom;

    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        keccak256("EIP712Domain(string name,string version,bytes32 salt)"),
        keccak256("BridgeAdmin"), // name hash
        keccak256("1"), // version hash
        keccak256(abi.encode("BRIDGE_ADMIN", roninChainId)) // salt
      )
    );
  }

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
   * @inheritdoc IQuorum
   */
  function setThreshold(
    uint256 _numerator,
    uint256 _denominator
  ) external override onlyAdmin returns (uint256, uint256) {
    return _setThreshold(_numerator, _denominator);
  }

  /**
   * @inheritdoc IQuorum
   */
  function minimumVoteWeight() public view virtual returns (uint256) {
    return (_num * _totalWeight + _denom - 1) / _denom;
  }

  /**
   * @inheritdoc IQuorum
   */
  function getThreshold() external view virtual returns (uint256 num_, uint256 denom_) {
    return (_num, _denom);
  }

  /**
   * @inheritdoc IQuorum
   */
  function checkThreshold(uint256 _voteWeight) external view virtual returns (bool) {
    return _voteWeight * _denom >= _num * _totalWeight;
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
   * @dev Sets threshold and returns the old one.
   *
   * Emits the `ThresholdUpdated` event.
   *
   */
  function _setThreshold(
    uint256 _numerator,
    uint256 _denominator
  ) internal virtual returns (uint256 _previousNum, uint256 _previousDenom) {
    if (_numerator > _denominator) revert ErrInvalidThreshold(msg.sig);

    _previousNum = _num;
    _previousDenom = _denom;
    _num = _numerator;
    _denom = _denominator;
    unchecked {
      emit ThresholdUpdated(_nonce++, _numerator, _denominator, _previousNum, _previousDenom);
    }
  }

  function _sumBridgeVoterWeights(address[] memory _bridgeVoters) internal view override returns (uint256) {
    return getSumBridgeVoterWeights(_bridgeVoters);
  }

  function _isBridgeVoter(address addr) internal view override returns (bool) {
    return _bridgeOperatorInfo()[addr].voteWeight != 0;
  }
}
