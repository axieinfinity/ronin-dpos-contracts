// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ICreditScore {
  /**
   * @dev Error thrown when an invalid credit score configuration is provided.
   */
  error ErrInvalidCreditScoreConfig();

  /**
   * @dev Error thrown when an invalid cut-off percentage configuration is provided.
   */
  error ErrInvalidCutOffPercentageConfig();

  /**
   * @dev Error thrown when the caller's credit score is insufficient to bail out a situation.
   */
  error ErrInsufficientCreditScoreToBailOut();

  /**
   * @dev Error thrown when a validator has previously bailed out.
   */
  error ErrValidatorHasBailedOutPreviously();

  /**
   * @dev Error thrown when the caller must be jailed in the current period.
   */
  error ErrCallerMustBeJailedInTheCurrentPeriod();

  /// @dev Emitted when the configs to credit score is updated. See the method `setCreditScoreConfigs` for param details.
  event CreditScoreConfigsUpdated(
    uint256 gainCreditScore,
    uint256 maxCreditScore,
    uint256 bailOutCostMultiplier,
    uint256 cutOffPercentageAfterBailout
  );
  /// @dev Emitted the credit score of validators is updated.
  event CreditScoresUpdated(address[] validators, uint256[] creditScores);
  /// @dev Emitted when a validator bailed out of jail.
  event BailedOut(address indexed validator, uint256 period, uint256 usedCreditScore);

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
  function updateCreditScores(address[] calldata _validators, uint256 _period) external;

  /**
   * @dev Resets the credit score for the revoked validators.
   *
   * Requirements:
   * - Only validator contract can call this method.
   * - This method is only called at the end of each period.
   *
   * Emits the event `CreditScoresUpdated`.
   *
   */
  function execResetCreditScores(address[] calldata _validators) external;

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
   * @param _gainScore The score to gain per period.
   * @param _maxScore The max number of credit score that a validator can hold.
   * @param _bailOutMultiplier The number that will be multiplied with the remaining jailed time to get the cost of bailing out.
   * @param _cutOffPercentage The percentage of reward that the block producer will be cut off from until the end of the period after bailing out.
   *
   */
  function setCreditScoreConfigs(
    uint256 _gainScore,
    uint256 _maxScore,
    uint256 _bailOutMultiplier,
    uint256 _cutOffPercentage
  ) external;

  /**
   * @dev Returns the configs related to credit score.
   *
   * @return _gainCreditScore The score to gain per period.
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
  function getManyCreditScores(address[] calldata _validators) external view returns (uint256[] memory _resultList);

  /**
   * @dev Returns the whether the `_validator` has been bailed out at the `_period`.
   */
  function checkBailedOutAtPeriod(address _validator, uint256 _period) external view returns (bool);
}
