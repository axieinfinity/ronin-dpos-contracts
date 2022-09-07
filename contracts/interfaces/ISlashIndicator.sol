// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../interfaces/IRoninValidatorSet.sol";

interface ISlashIndicator {
  // TODO: fill comment for event. IE: Emitted when...
  // TODO: add event for thresholds
  event ValidatorSlashed(address indexed validator, SlashType slashType);
  event UnavailabilityIndicatorsReset(address[] validators);

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
   * - Only governance admin contract can call this method
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
   * @dev Returns the governance admin contract address.
   */
  function governanceAdminContract() external view returns (address);
}
