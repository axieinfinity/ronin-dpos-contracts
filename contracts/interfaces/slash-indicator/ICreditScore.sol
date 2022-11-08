// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ICreditScore {
  /// @dev Emitted when the configs to credit score is updated. See the method `setCreditScoreConfigs` for param details.
  event CreditScoreConfigsUpdated(
    uint256 gainCreditScore,
    uint256 maxCreditScore,
    uint256 bailOutCostMultiplier,
    uint256 cutOffPercentageAfterBailout
  );
  /// @dev Emitted the credit score of validators is updated
  event CreditScoresUpdated(address[] validators, uint256[] creditScores);
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
   * Emits the event `BailedOut`.
   *
   */
  function bailOut(address _consensusAddr) external;

  /**
   * @dev Sets the configs to credit score.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the event `CreditScoreConfigsUpdated`.
   *
   * @param _gainCreditScore The max gained number of credit score per period.
   * @param _maxCreditScore The max number of credit score that a validator can hold.
   * @param _bailOutCostMultiplier The number that will be multiplied with the remaining jailed time to get the cost of bailing out.
   * @param _cutOffPercentageAfterBailout The percentage of reward that the validator will be cut off from until the end of the period after bailing out.
   *
   */
  function setCreditScoreConfigs(
    uint256 _gainCreditScore,
    uint256 _maxCreditScore,
    uint256 _bailOutCostMultiplier,
    uint256 _cutOffPercentageAfterBailout
  ) external;

  /**
   * @dev Returns the configs related to credit score.
   *
   * @return _gainCreditScore The max gained number of credit score per period.
   * @return _maxCreditScore The max number of credit score that a validator can hold.
   * @return _bailOutCostMultiplier The number that will be multiplied with the remaining jailed time to get the cost of bailing out.
   * @return _cutOffPercentageAfterBailout The percentage of reward that the block producer will be cut off from until the end of the period after bailing out.
   *
   */
  function getCreditScoreConfigs()
    external
    view
    returns (
      uint256 _gainCreditScore,
      uint256 _maxCreditScore,
      uint256 _bailOutCostMultiplier,
      uint256 _cutOffPercentageAfterBailout
    );

  /**
   * @dev Returns the current credit score of the validator.
   */
  function getCreditScore(address _validator) external view returns (uint256);

  /**
   * @dev Returns the current credit score of a list of validators.
   */
  function getBulkCreditScore(address[] calldata _validators) external view returns (uint256[] memory _resultList);

  /**
   * @dev Returns the whether the `_validator` has been bailed out at the `_period`.
   */
  function bailedOutAtPeriod(address _validator, uint256 _period) external view returns (bool);
}
