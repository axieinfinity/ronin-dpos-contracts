// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../interfaces/consumers/SignatureConsumer.sol";
import "../../interfaces/consumers/VoteStatusConsumer.sol";
import "../../libraries/Errors.sol";
import "../../libraries/BridgeOperatorsBallot.sol";
import "../../libraries/AddressArrayUtils.sol";
import "../../libraries/IsolatedGovernance.sol";

abstract contract BOsGovernanceRelay is SignatureConsumer, VoteStatusConsumer {
  /**
   * @dev Error indicating that the bridge operator set has already been voted.
   */
  error ErrBridgeOperatorSetIsAlreadyVoted();

  /// @dev The last the brige operator set info.
  BridgeOperatorsBallot.BridgeOperatorSet internal _lastSyncedBridgeOperatorSetInfo;
  /// @dev Mapping from period index => epoch index => bridge operators vote
  mapping(uint256 => mapping(uint256 => IsolatedGovernance.Vote)) internal _vote;

  /**
   * @dev Returns the synced bridge operator set info.
   */
  function lastSyncedBridgeOperatorSetInfo() external view returns (BridgeOperatorsBallot.BridgeOperatorSet memory) {
    return _lastSyncedBridgeOperatorSetInfo;
  }

  /**
   * @dev Relays votes by signatures.
   *
   * Requirements:
   * - The period of voting is larger than the last synced period.
   * - The arrays are not empty.
   * - The signature signers are in order.
   *
   * @notice Does not store the voter signature into storage.
   *
   */
  function _relayVotesBySignatures(
    BridgeOperatorsBallot.BridgeOperatorSet calldata _ballot,
    Signature[] calldata _signatures,
    uint256 _minimumVoteWeight,
    bytes32 _domainSeperator
  ) internal {
    if (
      _ballot.period < _lastSyncedBridgeOperatorSetInfo.period ||
      _ballot.epoch <= _lastSyncedBridgeOperatorSetInfo.epoch
    ) revert ErrQueryForOutdatedBridgeOperatorSet();

    BridgeOperatorsBallot.verifyBallot(_ballot);

    if (AddressArrayUtils.isEqual(_ballot.operators, _lastSyncedBridgeOperatorSetInfo.operators))
      revert ErrBridgeOperatorSetIsAlreadyVoted();

    if (_signatures.length == 0) revert ErrEmptyArray();

    Signature calldata _sig;
    address[] memory _signers = new address[](_signatures.length);
    address _lastSigner;
    bytes32 _hash = BridgeOperatorsBallot.hash(_ballot);
    bytes32 _digest = ECDSA.toTypedDataHash(_domainSeperator, _hash);

    for (uint256 _i = 0; _i < _signatures.length; ) {
      _sig = _signatures[_i];
      _signers[_i] = ECDSA.recover(_digest, _sig.v, _sig.r, _sig.s);
      if (_lastSigner >= _signers[_i]) revert ErrInvalidOrder(msg.sig);
      _lastSigner = _signers[_i];

      unchecked {
        ++_i;
      }
    }

    IsolatedGovernance.Vote storage _v = _vote[_ballot.period][_ballot.epoch];
    uint256 _totalVoteWeight = _sumBridgeVoterWeights(_signers);
    if (_totalVoteWeight >= _minimumVoteWeight) {
      if (_totalVoteWeight == 0) revert ErrInvalidVoteWeight(msg.sig);
      _v.status = VoteStatus.Approved;
      _lastSyncedBridgeOperatorSetInfo = _ballot;
      return;
    }

    revert ErrRelayFailed(msg.sig);
  }

  /**
   * @dev Returns the weight of the governor list.
   */
  function _sumBridgeVoterWeights(address[] memory _bridgeVoters) internal view virtual returns (uint256);
}
