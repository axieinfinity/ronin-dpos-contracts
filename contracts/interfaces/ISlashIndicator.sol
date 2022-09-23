// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ISlashIndicator {
  /// @dev Emitted when the validator is slashed for unavailability
  event UnavailabilitySlashed(address indexed validator, SlashType slashType, uint256 period);
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
   * Emits the event `UnavailabilitySlashed` when the threshold is reached.
   *
   */
  function slash(address _valAddr) external;

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
   * @dev Returns the current unavailability indicator of a validator.
   */
  function currentUnavailabilityIndicator(address _validator) external view returns (uint256);

  /**
   * @dev Retursn the unavailability indicator in the period `_period` of a validator.
   */
  function getUnavailabilityIndicator(address _validator, uint256 _period) external view returns (uint256);

  /**
   * @dev Gets the slash thresholds
   */
  function getSlashThresholds() external view returns (uint256 misdemeanorThreshold, uint256 felonyThreshold);

  /**
   * @dev Checks the slashed tier for unavailability of a validator.
   */
  function getUnavailabilitySlashType(address _validatorAddr, uint256 _period) external view returns (SlashType);

  /**
   * @dev Returns the scaled thresholds based on the maintenance duration for unavailability slashing.
   */
  function getUnavailabilityThresholds(address _addr, uint256 _block)
    external
    view
    returns (uint256 _felonyThreshold, uint256 _misdemeanorThreshold);
}
