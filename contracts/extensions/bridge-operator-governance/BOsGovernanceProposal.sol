// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../interfaces/consumers/SignatureConsumer.sol";
import "../../libraries/BridgeOperatorsBallot.sol";
import "../../interfaces/IBridgeAdminProposal.sol";
import "../../libraries/IsolatedGovernance.sol";

abstract contract BOsGovernanceProposal is SignatureConsumer, IBridgeAdminProposal {
  using IsolatedGovernance for IsolatedGovernance.Vote;
  /**
   * @dev Error indicating that the order of signers is invalid.
   */
  error ErrInvalidSignerOrder();

  /// @dev The last the brige operator set info.
  BridgeOperatorsBallot.BridgeOperatorSet internal _lastSyncedBridgeOperatorSetInfo;
  /// @dev Mapping from period index => epoch index => bridge operators vote
  mapping(uint256 => mapping(uint256 => IsolatedGovernance.Vote)) internal _bridgeOperatorVote;
  /// @dev Mapping from bridge voter address => last block that the address voted
  mapping(address => uint256) internal _lastVotedBlock;
  /// @dev Mapping from period index => epoch index => voter => bridge voter signatures
  mapping(uint256 => mapping(uint256 => mapping(address => Signature))) internal _bridgeVoterSig;

  /**
   * @inheritdoc IBridgeAdminProposal
   */
  function lastVotedBlock(address _bridgeVoter) external view returns (uint256) {
    return _lastVotedBlock[_bridgeVoter];
  }

  /**
   * @inheritdoc IBridgeAdminProposal
   */
  function lastSyncedBridgeOperatorSetInfo() external view returns (BridgeOperatorsBallot.BridgeOperatorSet memory) {
    return _lastSyncedBridgeOperatorSetInfo;
  }

  /**
   * @dev Votes for a set of bridge operators by signatures.
   *
   * Requirements:
   * - The period of voting is larger than the last synced period.
   * - The arrays are not empty.
   * - The signature signers are in order.
   *
   */
  function _castBOVotesBySignatures(
    BridgeOperatorsBallot.BridgeOperatorSet calldata _ballot,
    Signature[] calldata _signatures,
    uint256 _minimumVoteWeight,
    bytes32 _domainSeperator
  ) internal {
    if (
      _ballot.period < _lastSyncedBridgeOperatorSetInfo.period || _ballot.epoch < _lastSyncedBridgeOperatorSetInfo.epoch
    ) revert ErrQueryForOutdatedBridgeOperatorSet();

    BridgeOperatorsBallot.verifyBallot(_ballot);
    if (_signatures.length == 0) revert ErrEmptyArray();

    address _signer;
    address _lastSigner;
    bytes32 _hash = BridgeOperatorsBallot.hash(_ballot);
    bytes32 _digest = ECDSA.toTypedDataHash(_domainSeperator, _hash);
    IsolatedGovernance.Vote storage _v = _bridgeOperatorVote[_ballot.period][_ballot.epoch];
    mapping(address => Signature) storage _sigMap = _bridgeVoterSig[_ballot.period][_ballot.epoch];
    bool _hasValidVotes;

    for (uint256 _i; _i < _signatures.length; ) {
      // Avoids stack too deeps
      {
        Signature calldata _sig = _signatures[_i];
        _signer = ECDSA.recover(_digest, _sig.v, _sig.r, _sig.s);
        if (_lastSigner >= _signer) revert ErrInvalidSignerOrder();
        _lastSigner = _signer;
      }

      if (_isBridgeVoter(_signer)) {
        _hasValidVotes = true;
        _lastVotedBlock[_signer] = block.number;
        _sigMap[_signer] = _signatures[_i];
        _v.castVote(_signer, _hash);
      }

      unchecked {
        ++_i;
      }
    }

    if (!_hasValidVotes) revert ErrInvalidSignatures(msg.sig);
    address[] memory _filteredVoters = _v.filterByHash(_hash);
    _v.syncVoteStatus(_minimumVoteWeight, _sumBridgeVoterWeights(_filteredVoters), _hash);
  }

  /**
   * @dev Returns whether the address is the bridge voter.
   */
  function _isBridgeVoter(address) internal view virtual returns (bool);

  /**
   * @dev Returns the weight of many bridge voters.
   */
  function _sumBridgeVoterWeights(address[] memory _bridgeVoters) internal view virtual returns (uint256);
}
