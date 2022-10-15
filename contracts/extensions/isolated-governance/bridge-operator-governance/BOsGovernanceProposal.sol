// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../../extensions/isolated-governance/IsolatedGovernance.sol";
import "../../../interfaces/consumers/WeightedAddressConsumer.sol";
import "../../../interfaces/consumers/SignatureConsumer.sol";
import "../../../libraries/BridgeOperatorsBallot.sol";

abstract contract BOsGovernanceProposal is SignatureConsumer, WeightedAddressConsumer, IsolatedGovernance {
  /// @dev The last period that the brige operators synced.
  uint256 internal _lastSyncedPeriod;
  /// @dev Mapping from period index => bridge operators vote
  mapping(uint256 => IsolatedVote) internal _vote;

  /// @dev Mapping from governor address => last block that the governor voted
  mapping(address => uint256) internal _lastVotedBlock;
  /// @dev Mapping from period => voter => signatures
  mapping(uint256 => mapping(address => Signature)) internal _votingSig;

  /**
   * @dev Votes for a set of bridge operators by signatures.
   *
   * Requirements:
   * - The period of voting is larger than the last synced period.
   * - The arrays are not empty.
   * - The signature signers are in order.
   *
   */
  function _castVotesBySignatures(
    WeightedAddress[] calldata _operators,
    Signature[] calldata _signatures,
    uint256 _period,
    uint256 _minimumVoteWeight,
    bytes32 _domainSeperator
  ) internal {
    require(_period >= _lastSyncedPeriod, "BOsGovernanceProposal: query for outdated period");
    require(_operators.length > 0 && _signatures.length > 0, "BOsGovernanceProposal: invalid array length");

    Signature memory _sig;
    address _signer;
    address _lastSigner;
    bytes32 _hash = BridgeOperatorsBallot.hash(_period, _operators);
    bytes32 _digest = ECDSA.toTypedDataHash(_domainSeperator, _hash);
    IsolatedVote storage _v = _vote[_period];
    bool _hasValidVotes;

    for (uint256 _i = 0; _i < _signatures.length; _i++) {
      _sig = _signatures[_i];
      _signer = ECDSA.recover(_digest, _sig.v, _sig.r, _sig.s);
      require(_lastSigner < _signer, "BOsGovernanceProposal: invalid order");
      _lastSigner = _signer;

      uint256 _weight = _getWeight(_signer);
      if (_weight > 0) {
        _hasValidVotes = true;
        _lastVotedBlock[_signer] = block.number;
        _votingSig[_period][_signer] = _sig;
        if (_castVote(_v, _signer, _weight, _minimumVoteWeight, _hash) == VoteStatus.Approved) {
          return;
        }
      }
    }

    require(_hasValidVotes, "BOsGovernanceProposal: invalid signatures");
  }

  /**
   * @dev Returns the weight of a governor.
   */
  function _getWeight(address _governor) internal view virtual returns (uint256);
}
