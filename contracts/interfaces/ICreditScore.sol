// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ICreditScore {
  /// @dev Emitted the credit score of validators is updated
  event CreditScoresUpdated(address[] validators, uint256[] creditScores);
  /// @dev Emitted when the number of credit score a validator can redeem per an period is updated
  event GainCreditScoreUpdated(uint256 gainCreditScore);
  /// @dev Emitted when the max number of credit score a validator can hold is updated
  event MaxCreditScoreUpdated(uint256 maxCreditScore);
  /// @dev Emitted when the bail out cost multiplier to is updated
  event BailOutCostMultiplierUpdated(uint256 bailOutCostMultiplier);
  /// @dev Emitted when a validator bailed out of jail
  event BailedOut(address indexed validator, uint256 period);

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
   * @dev Returns the current credit score of the validator.
   */
  function getCreditScore(address _validator) external view returns (uint256);

  /**
   * @dev Returns the current credit score of a list of validators.
   */
  function getBulkCreditScore(address[] calldata _validators) external view returns (uint256[] memory _resultList);
}
