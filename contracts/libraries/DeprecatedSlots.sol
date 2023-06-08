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
  address private ____deprecatedSI;
}

contract HasStakingVestingDeprecated {
  address private ____deprecatedSV;
}

contract HasBridgeDeprecated {
  address private ____deprecatedB;
}

contract HasValidatorDeprecated {
  address private ____deprecatedV;
}

contract HasStakingDeprecated {
  address private ____deprecatedS;
}

contract HasMaintenanceDeprecated {
  address private ____deprecatedM;
}

contract HasTrustedOrgDeprecated {
  address private ____deprecatedRTO;
}

contract HasGovernanceAdminDeprecated {
  address private ____deprecatedRGA;
}

contract HasBridgeTrackingDeprecated {
  address private ____deprecatedBT;
}
