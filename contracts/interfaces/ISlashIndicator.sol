// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ISlashIndicator {
  enum SlashType {
    UNKNOWN,
    MISDEMEANOR,
    FELONY,
    DOUBLE_SIGNING,
    BRIDGE_VOTING
  }

  /// @dev Emitted when the validator is slashed for unavailability
  event UnavailabilitySlashed(address indexed validator, SlashType slashType, uint256 period);
  /// @dev Emitted the credit score of validators is updated
  event CreditScoresUpdated(address[] validators, uint256[] creditScores);
  /// @dev Emitted when the thresholds updated
  event SlashThresholdsUpdated(uint256 misdemeanorThreshold, uint256 felonyThreshold);
  /// @dev Emitted when the threshold to slash when trusted organization does not vote for bridge operators is updated
  event BridgeVotingThresholdUpdated(uint256 threshold);
  /// @dev Emitted when the amount of RON to slash bridge voting is updated
  event BridgeVotingSlashAmountUpdated(uint256 amount);
  /// @dev Emitted when the amount of slashing felony updated
  event SlashFelonyAmountUpdated(uint256 slashFelonyAmount);
  /// @dev Emitted when the amount of slashing double sign updated
  event SlashDoubleSignAmountUpdated(uint256 slashDoubleSignAmount);
  /// @dev Emitted when the duration of jailing felony updated
  event FelonyJailDurationUpdated(uint256 felonyJailDuration);
  /// @dev Emitted when the constrain of ahead block in double signing updated
  event DoubleSigningConstrainBlocksUpdated(uint256 doubleSigningConstrainBlocks);
  /// @dev Emitted when the block number to jail the double signing validator to is updated
  event DoubleSigningJailUntilBlockUpdated(uint256 doubleSigningJailUntilBlock);
  /// @dev Emitted when the number of credit score a validator can redeem per an period is updated
  event GainCreditScoreUpdated(uint256 gainCreditScore);
  /// @dev Emitted when the max number of credit score a validator can hold is updated
  event MaxCreditScoreUpdated(uint256 maxCreditScore);
  /// @dev Emitted when the bail out cost multiplier to is updated
  event BailOutCostMultiplierUpdated(uint256 bailOutCostMultiplier);
  /// @dev Emitted when a validator bailed out of jail
  event BailedOut(address indexed validator, uint256 period);

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
   * Emits the event `UnavailabilitySlashed` if the double signing evidence of the two headers valid
   */
  function slashDoubleSign(
    address _validatorAddr,
    bytes calldata _header1,
    bytes calldata _header2
  ) external;

  /**
   * @dev Slashes for bridge voter governance.
   *
   * Emits the event `UnavailabilitySlashed`.
   */
  function slashBridgeVoting(address _consensusAddr) external;

  /**
   * @dev Updates the credit score for the validators.
   *
   * Requirements:
   * - Only validator contract can call this method.
   * - This method is only called at the end of each period.
   *
   * Emits the event `CreditScoresUpdated`.
   *
   */
  function updateCreditScore(address[] calldata _validators, uint256 _period) external;

  /**
   * @dev A slashed validator use this method to get out of jail.
   *
   * Requirements:
   * - The `_consensusAddr` must be a validator.
   * - Only validator's admin can call this method.
   *
   */
  function bailOut(address _consensusAddr) external;

  /**
   * @dev Sets the slash thresholds
   *
   * Requirements:
   * - Only admin can call this method
   *
   * Emits the event `SlashThresholdsUpdated`
   *
   */
  function setSlashThresholds(uint256 _misdemeanorThreshold, uint256 _felonyThreshold) external;

  /**
   * @dev Sets the slash felony amount
   *
   * Requirements:
   * - Only admin can call this method
   *
   * Emits the event `SlashFelonyAmountUpdated`
   *
   */
  function setSlashFelonyAmount(uint256 _slashFelonyAmount) external;

  /**
   * @dev Sets the slash double sign amount
   *
   * Requirements:
   * - Only admin can call this method
   *
   * Emits the event `SlashDoubleSignAmountUpdated`
   *
   */
  function setSlashDoubleSignAmount(uint256 _slashDoubleSignAmount) external;

  /**
   * @dev Sets the felony jail duration
   *
   * Requirements:
   * - Only admin can call this method
   *
   * Emits the event `FelonyJailDurationUpdated`
   *
   */
  function setFelonyJailDuration(uint256 _felonyJailDuration) external;

  /**
   * @dev Sets the threshold to slash when trusted organization does not vote for bridge operators.
   *
   * Requirements:
   * - Only admin can call this method
   *
   * Emits the event `BridgeVotingThresholdUpdated`
   *
   */
  function setBridgeVotingThreshold(uint256 _threshold) external;

  /**
   * @dev Sets the amount of RON to slash bridge voting.
   *
   * Requirements:
   * - Only admin can call this method
   *
   * Emits the event `BridgeVotingSlashAmountUpdated`
   *
   */
  function setBridgeVotingSlashAmount(uint256 _amount) external;

  /**
   * @dev Sets the max gained number of credit score per period.
   *
   * Requirements:
   * - Only admin can call this method
   *
   * Emits the event `GainCreditScoreUpdated`
   *
   */
  function setGainCreditScore(uint256 _gainCreditScore) external;

  /**
   * @dev Sets the max number of credit score that a validator can hold.
   *
   * Requirements:
   * - Only admin can call this method
   *
   * Emits the event `MaxCreditScoreUpdated`
   *
   */
  function setMaxCreditScore(uint256 _maxCreditScore) external;

  /**
   * @dev Sets number that will be multiplied with the remaining jailed time to get the cost of bailing out.
   *
   * Requirements:
   * - Only admin can call this method
   *
   * Emits the event `BailOutCostMultiplierUpdated`
   *
   */
  function setBailOutCostMultiplier(uint256 _bailOutCostMultiplier) external;

  /**
   * @dev Returns the current unavailability indicator of a validator.
   */
  function currentUnavailabilityIndicator(address _validator) external view returns (uint256);

  /**
   * @dev Returns the unavailability indicator in the period `_period` of a validator.
   */
  function getUnavailabilityIndicator(address _validator, uint256 _period) external view returns (uint256);

  /**
   * @dev Returns the current credit score of the validator.
   */
  function getCreditScore(address _validator) external view returns (uint256);

  /**
   * @dev Returns the current credit score of a list of validators.
   */
  function getBulkCreditScore(address[] calldata _validators) external view returns (uint256[] memory _resultList);

  /**
   * @dev Gets the unavailability thresholds.
   */
  function getUnavailabilityThresholds()
    external
    view
    returns (uint256 _misdemeanorThreshold, uint256 _felonyThreshold);
}
