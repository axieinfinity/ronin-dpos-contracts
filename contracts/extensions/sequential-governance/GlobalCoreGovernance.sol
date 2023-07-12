// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../libraries/Proposal.sol";
import "../../libraries/GlobalProposal.sol";
import "./CoreGovernance.sol";

abstract contract GlobalCoreGovernance is CoreGovernance {
  using Proposal for Proposal.ProposalDetail;
  using GlobalProposal for GlobalProposal.GlobalProposalDetail;

  /// @dev Emitted when a proposal is created
  event GlobalProposalCreated(
    uint256 indexed round,
    bytes32 indexed proposalHash,
    Proposal.ProposalDetail proposal,
    bytes32 globalProposalHash,
    GlobalProposal.GlobalProposalDetail globalProposal,
    address creator
  );

  /**
   * @dev Proposes for a global proposal.
   *
   * Emits the `GlobalProposalCreated` event.
   *
   */
  function _proposeGlobal(
    uint256 _expiryTimestamp,
    GlobalProposal.TargetOption[] calldata _targetOptions,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    uint256[] memory _gasAmounts,
    address _bridgeManagerContract,
    address _gatewayContract,
    address _creator
  ) internal virtual {
    uint256 _round = _createVotingRound(0);
    GlobalProposal.GlobalProposalDetail memory _globalProposal = GlobalProposal.GlobalProposalDetail(
      _round,
      _expiryTimestamp,
      _targetOptions,
      _values,
      _calldatas,
      _gasAmounts
    );
    Proposal.ProposalDetail memory _proposal = _globalProposal.intoProposalDetail(
      _bridgeManagerContract,
      _gatewayContract
    );
    _proposal.validate(_proposalExpiryDuration);

    bytes32 _proposalHash = _proposal.hash();
    _saveVotingRound(vote[0][_round], _proposalHash, _expiryTimestamp);
    emit GlobalProposalCreated(_round, _proposalHash, _proposal, _globalProposal.hash(), _globalProposal, _creator);
  }

  /**
   * @dev Proposes global proposal struct.
   *
   * Requirements:
   * - The proposal nonce is equal to the new round.
   *
   * Emits the `GlobalProposalCreated` event.
   *
   */
  function _proposeGlobalStruct(
    GlobalProposal.GlobalProposalDetail memory _globalProposal,
    address _bridgeManagerContract,
    address _gatewayContract,
    address _creator
  ) internal virtual returns (Proposal.ProposalDetail memory _proposal) {
    _proposal = _globalProposal.intoProposalDetail(_bridgeManagerContract, _gatewayContract);
    _proposal.validate(_proposalExpiryDuration);

    bytes32 _proposalHash = _proposal.hash();
    uint256 _round = _createVotingRound(0);
    _saveVotingRound(vote[0][_round], _proposalHash, _globalProposal.expiryTimestamp);

    if (_round != _proposal.nonce) revert ErrInvalidProposalNonce(msg.sig);
    emit GlobalProposalCreated(_round, _proposalHash, _proposal, _globalProposal.hash(), _globalProposal, _creator);
  }
}
