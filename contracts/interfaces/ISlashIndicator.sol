// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../interfaces/IRoninValidatorSet.sol";

interface ISlashIndicator {
  /// @dev Emitted when the validator is slashed
  event ValidatorSlashed(address indexed validator, SlashType slashType);
  /// @dev Emitted when the validator indicators are reset
  event UnavailabilityIndicatorsReset(address[] validators);
  /// @dev Emitted when the address of governance admin is updated.
  event GovernanceAdminUpdated(address);

  enum SlashType {
    UNKNOWN,
    MISDEMEANOR,
    FELONY,
    DOUBLE_SIGNING
  }

  /**
   * @dev Returns the validator contract.
   */
  function validatorContract() external view returns (IRoninValidatorSet);

  /**
   * @dev Slashes for unavailability by increasing the counter of validator with `_valAddr`.
   * If the counter passes the threshold, call the function from the validator contract.
   *
   * Requirements:
   * - Only coinbase can call this method
   *
   * Emits the event `ValidatorSlashed`.
   *
   */
  function slash(address _valAddr) external;

  /**
   * @dev Resets the counter of all validators at the end of every period
   *
   * Requirements:
   * - Only validator contract can call this method
   *
   * Emits the `UnavailabilityIndicatorsReset` events.
   *
   */
  function resetCounters(address[] calldata) external;

  /**
   * @dev Slashes for double signing.
   *
   * Requirements:
   * - Only coinbase can call this method
   *
   */
  function slashDoubleSign(address _valAddr, bytes calldata _evidence) external;

  /**
   * @dev Sets the slash thresholds
   *
   * Requirements:
   * - Only governance admin can call this method
   *
   */
  function setSlashThresholds(uint256 _felonyThreshold, uint256 _misdemeanorThreshold) external;

  /**
   * @dev Gets slash indicator of a validator.
   */
  function getSlashIndicator(address _validator) external view returns (uint256);

  /**
   * @dev Gets the slash thresholds.
   */
  function getSlashThresholds() external view returns (uint256 misdemeanorThreshold, uint256 felonyThreshold);

  /**
   * @dev Returns the governance admin address.
   */
  function governanceAdmin() external view returns (address);

  ///////////////////////////////////////////////////////////////////////////////////////
  //                               GOVERNANCE FUNCTIONS                                //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Updates the governance admin
   *
   * Requirements:
   * - The method caller is the governance admin
   *
   * Emits the event `GovernanceAdminUpdated`
   *
   */
  function setGovernanceAdmin(address _governanceAdmin) external;
}
