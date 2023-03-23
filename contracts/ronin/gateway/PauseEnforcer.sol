// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "../../interfaces/IPauseTarget.sol";

contract PauseEnforcer is AccessControlEnumerable {
  bytes32 public constant SENTRY_ROLE = keccak256("SENTRY_ROLE");

  /// @dev The contract that can be paused or unpaused by the SENTRY_ROLE.
  IPauseTarget _target;
  /// @dev Indicating whether or not the target contract is paused in emergency mode.
  bool _emergency;

  modifier onEmergency() {
    require(_emergency, "PauseEnforcer: not on emergency pause");
    _;
  }

  modifier targetPaused() {
    require(_target.paused(), "PauseEnforcer: target is on pause");
    _;
  }

  modifier targetNotPaused() {
    require(!_target.paused(), "PauseEnforcer: target is not on pause");
    _;
  }

  constructor(address admin, IPauseTarget target) {
    _setupRole(DEFAULT_ADMIN_ROLE, admin);
    _target = target;
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
    _emergency = true;
    _target.pause();
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
    _emergency = false;
    _target.unpause();
  }
}
