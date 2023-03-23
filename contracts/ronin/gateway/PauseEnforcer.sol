// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "../../interfaces/IPauseTarget.sol";

contract PauseEnforcer is AccessControlEnumerable {
  bytes32 public constant SENTRY_ROLE = keccak256("SENTRY_ROLE");

  /// @dev The contract that can be paused or unpaused by the SENTRY_ROLE.
  IPauseTarget public target;
  /// @dev Indicating whether or not the target contract is paused in emergency mode.
  bool public emergency;

  modifier onEmergency() {
    require(emergency, "PauseEnforcer: not on emergency pause");
    _;
  }

  modifier targetPaused() {
    require(target.paused(), "PauseEnforcer: target is on pause");
    _;
  }

  modifier targetNotPaused() {
    require(!target.paused(), "PauseEnforcer: target is not on pause");
    _;
  }

  constructor(
    IPauseTarget _target,
    address _admin,
    address _sentry
  ) {
    target = _target;
    _setupRole(DEFAULT_ADMIN_ROLE, _admin);
    _grantRole(SENTRY_ROLE, _sentry);
  }

  /**
   * @dev Grants the SENTRY_ROLE to the specified address.
   */
  function grantSentry(address _sentry) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _grantRole(SENTRY_ROLE, _sentry);
  }

  /**
   * @dev Revokes the SENTRY_ROLE from the specified address.
   */
  function revokeSentry(address _sentry) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _revokeRole(SENTRY_ROLE, _sentry);
  }

  /**
   * @dev Triggers a pause on the target contract.
   *
   * Requirements:
   * - Only be called by accounts with the SENTRY_ROLE,
   * - The target contract is not already paused.
   */
  function triggerPause() external onlyRole(SENTRY_ROLE) targetNotPaused {
    emergency = true;
    target.pause();
  }

  /**
   * @dev Triggers an unpause on the target contract.
   *
   * Requirements:
   * - Only be called by accounts with the SENTRY_ROLE,
   * - The target contract is already paused.
   * - The target contract is paused in emergency mode.
   */
  function triggerUnpause() external onlyRole(SENTRY_ROLE) onEmergency targetPaused {
    emergency = false;
    target.unpause();
  }
}
