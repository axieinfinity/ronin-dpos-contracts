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
  address private ______deprecatedSI;
}

contract HasStakingVestingDeprecated {
  /// @custom:deprecated Previously `_stakingVestingContract` (non-zero value)
  address private ______deprecatedSV;
}

contract HasBridgeDeprecated {
  /// @custom:deprecated Previously `_bridgeContract` (non-zero value)
  address private ______deprecatedB;
}

contract HasValidatorDeprecated {
  /// @custom:deprecated Previously `_validatorContract` (non-zero value)
  address private ______deprecatedV;
}

contract HasStakingDeprecated {
  /// @custom:deprecated Previously `_stakingContract` (non-zero value)
  address private ______deprecatedS;
}

contract HasMaintenanceDeprecated {
  /// @custom:deprecated Previously `_maintenanceContract` (non-zero value)
  address private ______deprecatedM;
}

contract HasTrustedOrgDeprecated {
  /// @custom:deprecated Previously `_trustedOrgContract` (non-zero value)
  address private ______deprecatedRTO;
}

contract HasGovernanceAdminDeprecated {
  /// @custom:deprecated Previously `_governanceAdminContract` (non-zero value)
  address private ______deprecatedRGA;
}

contract HasBridgeTrackingDeprecated {
  /// @custom:deprecated Previously `_bridgeTrackingContract` (non-zero value)
  address private ______deprecatedBT;
}
