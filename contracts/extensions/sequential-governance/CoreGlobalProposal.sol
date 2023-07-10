// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Proposal } from "../../libraries/Proposal.sol";
import { GlobalProposal } from "../../libraries/GlobalProposal.sol";
import { CoreGovernance } from "./CoreGovernance.sol";
import { ErrInvalidProposalNonce } from "../../utils/CommonErrors.sol";

abstract contract CoreGlobalProposal is CoreGovernance {
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

  constructor(uint256 expiryDuration) {
    _setProposalExpiryDuration(expiryDuration);
  }

  /**
   * @dev Returns the expiry duration for a new proposal.
   */
  function _getProposalExpiryDuration() internal view returns (uint256) {
    return _proposalExpiryDuration;
  }

  /**
   * @dev Sets the expiry duration for a new proposal.
   */
  function _setProposalExpiryDuration(uint256 _expiryDuration) internal {
    _proposalExpiryDuration = _expiryDuration;
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
    address _bridgeManager,
    address _gatewayContract,
    address _creator
  ) internal virtual returns (Proposal.ProposalDetail memory _proposal) {
    _proposal = _globalProposal.intoProposalDetail(_bridgeManager, _gatewayContract);
    _proposal.validate(_proposalExpiryDuration);

    bytes32 _proposalHash = _proposal.hash();
    uint256 _round = _createVotingRound(0);
    _saveVotingRound(vote[0][_round], _proposalHash, _globalProposal.expiryTimestamp);

    if (_round != _proposal.nonce) revert ErrInvalidProposalNonce(msg.sig);
    emit GlobalProposalCreated(_round, _proposalHash, _proposal, _globalProposal.hash(), _globalProposal, _creator);
  }
}
