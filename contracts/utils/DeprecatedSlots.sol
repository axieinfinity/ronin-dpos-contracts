// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Deprecated Contracts
 * @dev These abstract contracts are deprecated and should not be used in new implementations.
 * They provide functionality related to various aspects of a smart contract but have been marked
 * as deprecated to indicate that they are no longer actively maintained or recommended for use.
 * The purpose of these contracts is to preserve the slots for already deployed contracts.
 */
contract HasSlashIndicatorDeprecated {
  /// @custom:deprecated Previously `_slashIndicatorContract` (non-zero value)
  address internal ______deprecatedSlashIndicator;
}

contract HasStakingVestingDeprecated {
  /// @custom:deprecated Previously `_stakingVestingContract` (non-zero value)
  address internal ______deprecatedStakingVesting;
}

contract HasBridgeDeprecated {
  /// @custom:deprecated Previously `_bridgeContract` (non-zero value)
  address internal ______deprecatedBridge;
}

contract HasValidatorDeprecated {
  /// @custom:deprecated Previously `_validatorContract` (non-zero value)
  address internal ______deprecatedValidator;
}

contract HasStakingDeprecated {
  /// @custom:deprecated Previously `_stakingContract` (non-zero value)
  address internal ______deprecatedStakingContract;
}

contract HasMaintenanceDeprecated {
  /// @custom:deprecated Previously `_maintenanceContract` (non-zero value)
  address internal ______deprecatedMaintenance;
}

contract HasTrustedOrgDeprecated {
  /// @custom:deprecated Previously `_trustedOrgContract` (non-zero value)
  address internal ______deprecatedTrustedOrg;
}

contract HasGovernanceAdminDeprecated {
  /// @custom:deprecated Previously `_governanceAdminContract` (non-zero value)
  address internal ______deprecatedGovernanceAdmin;
}

contract HasBridgeTrackingDeprecated {
  /// @custom:deprecated Previously `_bridgeTrackingContract` (non-zero value)
  address internal ______deprecatedBridgeTracking;
}
