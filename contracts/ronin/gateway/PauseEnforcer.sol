// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../interfaces/IPauseTarget.sol";

contract PauseEnforcer is AccessControlEnumerable, Initializable {
  /**
   * @dev Error thrown when the target is already on paused state.
   */
  error ErrTargetIsOnPaused();

  /**
   * @dev Error thrown when the target is not on paused state.
   */
  error ErrTargetIsNotOnPaused();

  /**
   * @dev Error thrown when the contract is not on emergency pause.
   */
  error ErrNotOnEmergencyPause();

  bytes32 public constant SENTRY_ROLE = keccak256("SENTRY_ROLE");

  /// @dev The contract that can be paused or unpaused by the SENTRY_ROLE.
  IPauseTarget public target;
  /// @dev Indicating whether or not the target contract is paused in emergency mode.
  bool public emergency;

  /// @dev Emitted when the emergency ppause is triggered by `account`.
  event EmergencyPaused(address account);
  /// @dev Emitted when the emergency unpause is triggered by `account`.
  event EmergencyUnpaused(address account);
  /// @dev Emitted when the target is changed.
  event TargetChanged(IPauseTarget target);

  modifier onEmergency() {
    if (!emergency) revert ErrNotOnEmergencyPause();

    _;
  }

  modifier targetPaused() {
    if (!target.paused()) revert ErrTargetIsOnPaused();

    _;
  }

  modifier targetNotPaused() {
    if (target.paused()) revert ErrTargetIsNotOnPaused();

    _;
  }

  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(IPauseTarget _target, address _admin, address[] memory _sentries) external initializer {
    _changeTarget(_target);
    _setupRole(DEFAULT_ADMIN_ROLE, _admin);
    for (uint _i; _i < _sentries.length; ) {
      _grantRole(SENTRY_ROLE, _sentries[_i]);

      unchecked {
        ++_i;
      }
    }
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
    emit EmergencyPaused(msg.sender);
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
    emit EmergencyUnpaused(msg.sender);
  }

  /**
   * @dev Setter for `target`.
   *
   * Requirements:
   * - Only admin can call this method.
   */
  function changeTarget(IPauseTarget _target) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _changeTarget(_target);
  }

  /**
   * @dev Internal helper for setting value to `target`.
   */
  function _changeTarget(IPauseTarget _target) internal {
    target = _target;
    emit TargetChanged(_target);
  }
}
