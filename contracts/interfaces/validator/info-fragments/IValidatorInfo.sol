// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IValidatorInfo {
  /// @dev Emitted when the number of max validator is updated.
  event MaxValidatorNumberUpdated(uint256);
  /// @dev Emitted when the number of reserved slots for prioritized validators is updated.
  event MaxPrioritizedValidatorNumberUpdated(uint256);

  /// @dev Error of number of prioritized greater than number of max validators.
  error ErrInvalidMaxPrioritizedValidatorNumber();

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
  function getValidators() external view returns (address[] memory);

  /**
   * @dev Returns whether the address is either a bridge operator or a block producer.
   */
  function isValidator(address _addr) external view returns (bool);

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
  function totalBlockProducers() external view returns (uint256);

  /**
   * @dev Returns the current bridge operator list.
   */
  function getBridgeOperators() external view returns (address[] memory);

  /**
   * @dev Returns the bridge operator list corresponding to validator address list.
   */
  function getBridgeOperatorsOf(address[] memory _validatorAddrs) external view returns (address[] memory);

  /**
   * @dev Returns whether the address is bridge operator or not.
   */
  function isBridgeOperator(address _addr) external view returns (bool);

  /**
   * @dev Returns whether the consensus address is operating the bridge or not.
   */
  function isOperatingBridge(address _consensusAddr) external view returns (bool);

  /**
   * @dev Returns total numbers of the bridge operators.
   */
  function totalBridgeOperators() external view returns (uint256);

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
