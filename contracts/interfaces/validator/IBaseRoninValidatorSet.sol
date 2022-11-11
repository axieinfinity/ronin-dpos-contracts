// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IBaseRoninValidatorSet {
  /// @dev Emitted when the number of max validator is updated
  event MaxValidatorNumberUpdated(uint256);
  /// @dev Emitted when the number of reserved slots for prioritized validators is updated
  event MaxPrioritizedValidatorNumberUpdated(uint256);
  /// @dev Emitted when the number of blocks in epoch is updated
  event NumberOfBlocksInEpochUpdated(uint256);

  ///////////////////////////////////////////////////////////////////////////////////////
  //                             FUNCTIONS FOR NORMAL USER                             //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Returns the maximum number of validators in the epoch
   */
  function maxValidatorNumber() external view returns (uint256 _maximumValidatorNumber);

  /**
   * @dev Returns the number of reserved slots for prioritized validators
   */
  function maxPrioritizedValidatorNumber() external view returns (uint256 _maximumPrioritizedValidatorNumber);

  ///////////////////////////////////////////////////////////////////////////////////////
  //                               FUNCTIONS FOR ADMIN                                 //
  ///////////////////////////////////////////////////////////////////////////////////////

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
