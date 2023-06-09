// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Deprecated Contracts
 * @dev These abstract contracts are deprecated and should not be used in new implementations.
 * They provide functionality related to various aspects of a smart contract but have been marked
 * as deprecated to indicate that they are no longer actively maintained or recommended for use.
 * @notice The reason for these contracts is for preserving the slots for already deployed contracts.
 */
contract HasSlashIndicatorDeprecated {
  /// @dev deprecated slot for SlashIndicatorContract
  address private ____deprecatedSI;
}

contract HasStakingVestingDeprecated {
  /// @dev deprecated slot for StakingVestingContract
  address private ____deprecatedSV;
}

contract HasBridgeDeprecated {
  /// @dev deprecated slot for BridgeContract
  address private ____deprecatedB;
}

contract HasValidatorDeprecated {
  address private ____deprecatedV;
}

contract HasStakingDeprecated {
  /// @dev deprecated slot for StakingContract
  address private ____deprecatedS;
}

contract HasMaintenanceDeprecated {
  /// @dev deprecated slot for MaintenanceContract
  address private ____deprecatedM;
}

contract HasTrustedOrgDeprecated {
  /// @dev deprecated slot for RoninTrustedOrganizationContract
  address private ____deprecatedRTO;
}

contract HasGovernanceAdminDeprecated {
  /// @dev deprecated slot for RoninGorvernanceAdminContract
  address private ____deprecatedRGA;
}

contract HasBridgeTrackingDeprecated {
  /// @dev deprecated slot for BridgeTrackingContract
  address private ____deprecatedBT;
}
