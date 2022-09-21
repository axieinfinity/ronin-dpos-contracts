// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ISlashIndicator {
  /// @dev Emitted when the validator is slashed
  event ValidatorSlashed(address indexed validator, SlashType slashType);
  /// @dev Emitted when the validator indicators are reset
  event UnavailabilityIndicatorsReset(address[] validators);
  /// @dev Emitted when the thresholds updated
  event SlashThresholdsUpdated(uint256 felonyThreshold, uint256 misdemeanorThreshold);
  /// @dev Emitted when the amount of slashing felony updated
  event SlashFelonyAmountUpdated(uint256 slashFelonyAmount);
  /// @dev Emitted when the amount of slashing double sign updated
  event SlashDoubleSignAmountUpdated(uint256 slashDoubleSignAmount);
  /// @dev Emiited when the duration of jailing felony updated
  event FelonyJailDurationUpdated(uint256 felonyJailDuration);

  enum SlashType {
    UNKNOWN,
    MISDEMEANOR,
    FELONY,
    DOUBLE_SIGNING
  }

  /**
   * @dev Slashes for unavailability by increasing the counter of validator with `_valAddr`.
   * If the counter passes the threshold, call the function from the validator contract.
   *
   * Requirements:
   * - Only coinbase can call this method
   *
   * Emits the event `ValidatorSlashed`
   *
   */
  function slash(address _valAddr) external;

  /**
   * @dev Resets the counter of all validators at the end of every period
   *
   * Requirements:
   * - Only validator contract can call this method
   *
   * Emits the `UnavailabilityIndicatorsReset` events
   *
   */
  function resetCounters(address[] calldata) external;

  /**
   * @dev Slashes for double signing
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
   * Emits the event `SlashThresholdsUpdated`
   *
   */
  function setSlashThresholds(uint256 _felonyThreshold, uint256 _misdemeanorThreshold) external;

  /**
   * @dev Sets the slash felony amount
   *
   * Requirements:
   * - Only governance admin can call this method
   *
   * Emits the event `SlashFelonyAmountUpdated`
   *
   */
  function setSlashFelonyAmount(uint256 _slashFelonyAmount) external;

  /**
   * @dev Sets the slash double sign amount
   *
   * Requirements:
   * - Only governance admin can call this method
   *
   * Emits the event `SlashDoubleSignAmountUpdated`
   *
   */
  function setSlashDoubleSignAmount(uint256 _slashDoubleSignAmount) external;

  /**
   * @dev Sets the felony jail duration
   *
   * Requirements:
   * - Only governance admin can call this method
   *
   * Emits the event `FelonyJailDurationUpdated`
   *
   */
  function setFelonyJailDuration(uint256 _felonyJailDuration) external;

  /**
   * @dev Gets slash indicator of a validator
   */
  function getSlashIndicator(address _validator) external view returns (uint256);

  /**
   * @dev Gets the slash thresholds
   */
  function getSlashThresholds() external view returns (uint256 misdemeanorThreshold, uint256 felonyThreshold);
}
