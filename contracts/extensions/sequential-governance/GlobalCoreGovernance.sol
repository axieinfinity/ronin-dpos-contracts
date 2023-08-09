// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../libraries/Proposal.sol";
import "../../libraries/GlobalProposal.sol";
import "./CoreGovernance.sol";

abstract contract GlobalCoreGovernance is CoreGovernance {
  using Proposal for Proposal.ProposalDetail;
  using GlobalProposal for GlobalProposal.GlobalProposalDetail;

  mapping(GlobalProposal.TargetOption => address) internal _targetOptionsMap;

  /// @dev Emitted when a proposal is created
  event GlobalProposalCreated(
    uint256 indexed round,
    bytes32 indexed proposalHash,
    Proposal.ProposalDetail proposal,
    bytes32 globalProposalHash,
    GlobalProposal.GlobalProposalDetail globalProposal,
    address creator
  );

  event TargetOptionsUpdated(GlobalProposal.TargetOption[] indexed targetOptions, address[] indexed addrs);

  constructor(GlobalProposal.TargetOption[] memory targetOptions, address[] memory addrs) {
    _updateTargetOptions(targetOptions, addrs);
  }

  /**
   * @dev Proposes for a global proposal.
   *
   * Emits the `GlobalProposalCreated` event.
   *
   */
  function _proposeGlobal(
    uint256 expiryTimestamp,
    GlobalProposal.TargetOption[] calldata targetOptions,
    uint256[] memory values,
    bytes[] memory calldatas,
    uint256[] memory gasAmounts,
    address creator
  ) internal virtual {
    uint256 round_ = _createVotingRound(0);
    GlobalProposal.GlobalProposalDetail memory _globalProposal = GlobalProposal.GlobalProposalDetail(
      round_,
      expiryTimestamp,
      targetOptions,
      values,
      calldatas,
      gasAmounts
    );
    Proposal.ProposalDetail memory proposal = _globalProposal.intoProposalDetail(
      _resolveTargets({ targetOptions: targetOptions, strict: true })
    );
    proposal.validate(_proposalExpiryDuration);

    bytes32 proposalHash = proposal.hash();
    _saveVotingRound(vote[0][round_], proposalHash, expiryTimestamp);
    emit GlobalProposalCreated(round_, proposalHash, proposal, _globalProposal.hash(), _globalProposal, creator);
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
    GlobalProposal.GlobalProposalDetail memory globalProposal,
    address creator
  ) internal virtual returns (Proposal.ProposalDetail memory proposal) {
    proposal = globalProposal.intoProposalDetail(
      _resolveTargets({ targetOptions: globalProposal.targetOptions, strict: true })
    );
    proposal.validate(_proposalExpiryDuration);

    bytes32 proposalHash = proposal.hash();
    uint256 round_ = _createVotingRound(0);
    _saveVotingRound(vote[0][round_], proposalHash, globalProposal.expiryTimestamp);

    if (round_ != proposal.nonce) revert ErrInvalidProposalNonce(msg.sig);
    emit GlobalProposalCreated(round_, proposalHash, proposal, globalProposal.hash(), globalProposal, creator);
  }

  /**
   * @dev Returns corresponding address of target options. Return address(0) on non-existent target.
   */
  function resolveTargets(
    GlobalProposal.TargetOption[] calldata targetOptions
  ) external view returns (address[] memory targets) {
    return _resolveTargets({ targetOptions: targetOptions, strict: false });
  }

  /**
   * @dev Internal helper of {resolveTargets}.
   *
   * @param strict When the param is set to `true`, revert on non-existent target.
   */
  function _resolveTargets(
    GlobalProposal.TargetOption[] memory targetOptions,
    bool strict
  ) internal view returns (address[] memory targets) {
    targets = new address[](targetOptions.length);

    for (uint256 i; i < targetOptions.length; ) {
      targets[i] = _targetOptionsMap[targetOptions[i]];
      if (strict && targets[i] == address(0)) revert ErrInvalidArguments(msg.sig);
      unchecked {
        ++i;
      }
    }
  }

  /**
   * @dev Updates list of `targetOptions to `targets`.
   *
   * Requirement:
   * - Only allow self-call through proposal.
   * */
  function updateTargetOptions(GlobalProposal.TargetOption[] memory targetOptions, address[] memory targets) external {
    // HACK: Cannot reuse the existing library due to too deep stack
    if (msg.sender != address(this)) revert ErrOnlySelfCall(msg.sig);
    _updateTargetOptions(targetOptions, targets);
  }

  /**
   * @dev Updates list of `targetOptions to `targets`.
   *
   * Requirement:
   * - Emit a `TargetOptionsUpdated` event.
   */
  function _updateTargetOptions(GlobalProposal.TargetOption[] memory targetOptions, address[] memory targets) internal {
    for (uint256 i; i < targetOptions.length; ) {
      _targetOptionsMap[targetOptions[i]] = targets[i];
      unchecked {
        ++i;
      }
    }

    emit TargetOptionsUpdated(targetOptions, targets);
  }
}
