// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { HasValidatorDeprecated, HasTrustedOrgDeprecated, HasGovernanceAdminDeprecated } from "../../utils/DeprecatedSlots.sol";
import "../../extensions/collections/HasContracts.sol";

// TODO: remove this from slashing logic of consensus contract
abstract contract DeprecatedSlashBridgeVoting is
  HasContracts,
  HasValidatorDeprecated,
  HasTrustedOrgDeprecated,
  HasGovernanceAdminDeprecated
{
  /// @dev Mapping from validator address => period index => bridge voting slashed
  mapping(address => mapping(uint256 => bool)) private __deprecatedBridgeVotingSlashed;
  /// @dev The threshold to slash when a trusted organization does not vote for bridge operators.
  uint256 private __deprecatedBridgeVotingThreshold;
  /// @dev The amount of RON to slash bridge voting.
  uint256 private __deprecatedBridgeVotingSlashAmount;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private ______gap;
}
