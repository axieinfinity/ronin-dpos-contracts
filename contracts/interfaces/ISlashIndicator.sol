// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../interfaces/IRoninValidatorSet.sol";

interface ISlashIndicator {
  // TODO: fill comment for event. IE: Emitted when...
  event ValidatorSlashed(address indexed validator, SlashType slashType);
  event UnavailabilityIndicatorReset(address indexed validator);

  enum SlashType {
    UNKNOWN,
    MISDEMAENOR,
    FELONY,
    DOUBLE_SIGNING
  }

  struct Indicator {
    /// @dev The block height that the indicator get updated, make sure this update once each block
    uint256 lastSyncedBlock;
    /// @dev Number of missed block the validator, reset everyday or once reaching the fenoly threshold
    uint128 counter;
  }

  /**
   * @dev Returns the validator contract.
   */
  function validatorContract() external view returns (IRoninValidatorSet);

  /**
   * @dev Slashs for inavailability by increasing the counter of validator with `_valAddr`.
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
   * @dev Resets the counter of the validator at the end of every period
   *
   * Requirements:
   * - Only validator contract can call this method
   *
   * Emits the event `UnavailabilityIndicatorReset`.
   *
   */
  function resetCounter(address) external;

  /**
   * @dev Resets the counter of all validators at the end of every period
   *
   * Requirements:
   * - Only validator contract can call this method
   *
   * Emits the `UnavailabilityIndicatorReset` events.
   *
   */
  function resetCounters(address[] calldata) external;

  /**
   * @dev Slashs for double signing.
   *
   * Requirements:
   * - Only coinbase can call this method
   *
   */
  function slashDoubleSign(address _valAddr, bytes calldata _evidence) external;

  /**
   * @dev Gets slash indicator of a validator.
   */
  function getSlashIndicator(address _validator) external view returns (Indicator memory);

  /**
   * @dev Gets slash threshold.
   */
  function getSlashThresholds() external view returns (uint256 misdemeanorThreshold, uint256 felonyThreshold);
}
