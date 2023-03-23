// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

interface PauseTarget {
  function pause() external;

  function unpause() external;

  function paused() external returns (bool);
}

contract PauseEnforcer is AccessControlEnumerable {
  bytes32 public constant SENTRY_ROLE = keccak256("SENTRY_ROLE");
  PauseTarget _target;
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

  constructor(address admin, PauseTarget target) {
    _setupRole(DEFAULT_ADMIN_ROLE, admin);
    _target = target;
  }

  function grantSentry(address _sentry) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _grantRole(SENTRY_ROLE, _sentry);
  }

  function revokeSentry(address _sentry) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _revokeRole(SENTRY_ROLE, _sentry);
  }

  function triggerPause() external onlyRole(SENTRY_ROLE) targetNotPaused {
    _emergency = true;
    _target.pause();
  }

  function triggerUnpause() external onlyRole(SENTRY_ROLE) onEmergency targetPaused {
    _emergency = false;
    _target.unpause();
  }
}
