// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../../libraries/EnumFlags.sol";

interface IValidatorInfoV2 {
  /**
   * @dev Error thrown when an invalid maximum prioritized validator number is provided.
   */
  error ErrInvalidMaxPrioritizedValidatorNumber();

  /// @dev Emitted when the number of max validator is updated.
  event MaxValidatorNumberUpdated(uint256);
  /// @dev Emitted when the number of reserved slots for prioritized validators is updated.
  event MaxPrioritizedValidatorNumberUpdated(uint256);

  /**
   * @dev Returns the maximum number of validators in the epoch.
   */
  function maxValidatorNumber() external view returns (uint256 _maximumValidatorNumber);

  /**
   * @dev Returns the number of reserved slots for prioritized validators.
   */
  function maxPrioritizedValidatorNumber() external view returns (uint256 _maximumPrioritizedValidatorNumber);

  /**
   * @dev Returns the current validator list.
   */
  function getValidators() external view returns (address[] memory _validatorList);

  /**
   * @dev Returns the current block producer list.
   */
  function getBlockProducers() external view returns (address[] memory);

  /**
   * @dev Returns whether the address is block producer or not.
   */
  function isBlockProducer(address _addr) external view returns (bool);

  /**
   * @dev Returns total numbers of the block producers.
   */
  function totalBlockProducer() external view returns (uint256);

  /**
   * @dev Updates the max validator number
   *
   * Requirements:
   * - The method caller is admin
   *
   * Emits the event `MaxValidatorNumberUpdated`
   *
   */
  function setMaxValidatorNumber(uint256 _maxValidatorNumber) external;

  /**
   * @dev Updates the number of reserved slots for prioritized validators
   *
   * Requirements:
   * - The method caller is admin
   *
   * Emits the event `MaxPrioritizedValidatorNumberUpdated`
   *
   */
  function setMaxPrioritizedValidatorNumber(uint256 _maxPrioritizedValidatorNumber) external;
}
