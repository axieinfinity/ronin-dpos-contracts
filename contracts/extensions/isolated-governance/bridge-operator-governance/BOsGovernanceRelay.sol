// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../extensions/isolated-governance/IsolatedGovernance.sol";
import "../../../interfaces/consumers/SignatureConsumer.sol";
import "../../../libraries/BridgeOperatorsBallot.sol";

abstract contract BOsGovernanceRelay is SignatureConsumer, IsolatedGovernance {
  /// @dev The last period that the brige operators synced.
  uint256 internal _lastSyncedPeriod;
  /// @dev The last epoch that the brige operators synced.
  uint256 internal _lastSyncedEpoch;
  /// @dev Mapping from period index => epoch index => bridge operators vote
  mapping(uint256 => mapping(uint256 => IsolatedVote)) internal _vote;

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
    address[] calldata _operators,
    Signature[] calldata _signatures,
    uint256 _period,
    uint256 _epoch,
    uint256 _minimumVoteWeight,
    bytes32 _domainSeperator
  ) internal {
    require(
      (_period >= _lastSyncedPeriod && _epoch > _lastSyncedEpoch),
      "BOsGovernanceRelay: query for outdated bridge operator set"
    );
    require(_operators.length > 0 && _signatures.length > 0, "BOsGovernanceRelay: invalid array length");

    Signature memory _sig;
    address[] memory _signers = new address[](_signatures.length);
    address _lastSigner;
    bytes32 _hash = BridgeOperatorsBallot.hash(_period, _epoch, _operators);
    bytes32 _digest = ECDSA.toTypedDataHash(_domainSeperator, _hash);

    for (uint256 _i = 0; _i < _signatures.length; _i++) {
      _sig = _signatures[_i];
      _signers[_i] = ECDSA.recover(_digest, _sig.v, _sig.r, _sig.s);
      require(_lastSigner < _signers[_i], "BOsGovernanceRelay: invalid order");
      _lastSigner = _signers[_i];
    }

    IsolatedVote storage _v = _vote[_period][_epoch];
    uint256 _totalVoteWeight = _sumBridgeVoterWeights(_signers);
    if (_totalVoteWeight >= _minimumVoteWeight) {
      require(_totalVoteWeight > 0, "BOsGovernanceRelay: invalid vote weight");
      _v.status = VoteStatus.Approved;
      _lastSyncedPeriod = _period;
      _lastSyncedEpoch = _epoch;
      return;
    }

    revert("BOsGovernanceRelay: relay failed");
  }

  /**
   * @dev Returns the weight of the governor list.
   */
  function _sumBridgeVoterWeights(address[] memory _bridgeVoters) internal view virtual returns (uint256);
}
