// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../interfaces/slash-indicator/ICreditScore.sol";
import "../../extensions/collections/HasMaintenanceContract.sol";
import "../../extensions/collections/HasValidatorContract.sol";
import "../../extensions/consumers/PercentageConsumer.sol";
import "../../libraries/Math.sol";

abstract contract CreditScore is ICreditScore, HasValidatorContract, HasMaintenanceContract, PercentageConsumer {
  /// @dev Mapping from validator address => period index => whether bailed out before
  mapping(address => mapping(uint256 => bool)) internal _bailedOutAtPeriod;
  /// @dev Mapping from validator address => credit score
  mapping(address => uint256) internal _creditScore;

  /// @dev The max gained number of credit score per period.
  uint256 public gainCreditScore;
  /// @dev The max number of credit score that a validator can hold.
  uint256 public maxCreditScore;
  /// @dev The number that will be multiplied with the remaining jailed time to get the cost of bailing out.
  uint256 public bailOutCostMultiplier;
  /// @dev The percentage of reward to be cut off from the validator in the rest of the period after bailed out.
  uint256 public cutOffPercentageAfterBailout;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private ______gap;

  ///////////////////////////////////////////////////////////////////////////////////////
  //                              CREDIT SCORE FUNCTIONS                               //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc ICreditScore
   */
  function updateCreditScore(address[] calldata _validators, uint256 _period) external override onlyValidatorContract {
    uint256 _periodStartAtBlock = _validatorContract.currentPeriodStartAtBlock();

    bool[] memory _jaileds = _validatorContract.bulkJailed(_validators);
    bool[] memory _maintaineds = _maintenanceContract.bulkMaintainingInBlockRange(
      _validators,
      _periodStartAtBlock,
      block.number
    );
    uint256[] memory _updatedCreditScores = new uint256[](_validators.length);

    for (uint _i = 0; _i < _validators.length; _i++) {
      address _validator = _validators[_i];

      uint256 _indicator = getUnavailabilityIndicator(_validator, _period);
      bool _isJailedInPeriod = _jaileds[_i];
      bool _isMaintainingInPeriod = _maintaineds[_i];

      uint256 _actualGain = (_isJailedInPeriod || _isMaintainingInPeriod)
        ? 0
        : Math.subNonNegative(gainCreditScore, _indicator);
      uint256 _scoreBeforeGain = _creditScore[_validator];
      uint256 _scoreAfterGain = Math.addWithUpperbound(_creditScore[_validator], _actualGain, maxCreditScore);

      if (_scoreBeforeGain != _scoreAfterGain) {
        _creditScore[_validator] = _scoreAfterGain;
      }

      _updatedCreditScores[_i] = _creditScore[_validator];
    }

    emit CreditScoresUpdated(_validators, _updatedCreditScores);
  }

  /**
   * @inheritdoc ICreditScore
   */
  function bailOut(address _consensusAddr) external override {
    require(
      _validatorContract.isValidatorCandidate(_consensusAddr),
      "SlashIndicator: consensus address must be a validator candidate"
    );
    require(
      _validatorContract.isCandidateAdmin(_consensusAddr, msg.sender),
      "SlashIndicator: method caller must be a candidate admin"
    );

    (bool _isJailed, , uint256 _jailedEpochLeft) = _validatorContract.jailedTimeLeft(_consensusAddr);
    require(_isJailed, "SlashIndicator: caller must be jailed in the current period");

    uint256 _period = _validatorContract.currentPeriod();
    require(!_bailedOutAtPeriod[_consensusAddr][_period], "SlashIndicator: validator has bailed out previously");

    uint256 _score = _creditScore[_consensusAddr];
    uint256 _cost = _jailedEpochLeft * bailOutCostMultiplier;
    require(_score >= _cost, "SlashIndicator: insufficient credit score to bail out");

    _validatorContract.bailOut(_consensusAddr, _period);

    _creditScore[_consensusAddr] -= _cost;
    _setUnavailabilityIndicator(_consensusAddr, _period, 0);
    _bailedOutAtPeriod[_consensusAddr][_period] = true;
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                               GOVERNANCE FUNCTIONS                                //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc ICreditScore
   */
  function setCreditScoreConfigs(
    uint256 _gainCreditScore,
    uint256 _maxCreditScore,
    uint256 _bailOutCostMultiplier,
    uint256 _cutOffPercentageAfterBailout
  ) external override onlyAdmin {
    _setCreditScoreConfigs(_gainCreditScore, _maxCreditScore, _bailOutCostMultiplier, _cutOffPercentageAfterBailout);
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                                  QUERY FUNCTIONS                                  //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev See `ISlashUnavailability`
   */
  function getUnavailabilityIndicator(address _validator, uint256 _period) public view virtual returns (uint256);

  /**
   * @inheritdoc ICreditScore
   */
  function getCreditScoreConfigs()
    external
    view
    override
    returns (
      uint256 _gainCreditScore,
      uint256 _maxCreditScore,
      uint256 _bailOutCostMultiplier,
      uint256 _cutOffPercentageAfterBailout
    )
  {
    _gainCreditScore = gainCreditScore;
    _maxCreditScore = maxCreditScore;
    _bailOutCostMultiplier = bailOutCostMultiplier;
    _cutOffPercentageAfterBailout = cutOffPercentageAfterBailout;
  }

  /**
   * @inheritdoc ICreditScore
   */
  function getCreditScore(address _validator) external view override returns (uint256) {
    return _creditScore[_validator];
  }

  /**
   * @inheritdoc ICreditScore
   */
  function getBulkCreditScore(address[] calldata _validators)
    public
    view
    override
    returns (uint256[] memory _resultList)
  {
    _resultList = new uint256[](_validators.length);

    for (uint _i = 0; _i < _resultList.length; _i++) {
      _resultList[_i] = _creditScore[_validators[_i]];
    }
  }

  /**
   * @inheritdoc ICreditScore
   */
  function bailedOutAtPeriod(address _validator, uint256 _period) external view override returns (bool) {
    return _bailedOutAtPeriod[_validator][_period];
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                                 HELPER FUNCTIONS                                  //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev See `ISlashUnavailability`
   */
  function _setUnavailabilityIndicator(
    address _validator,
    uint256 _period,
    uint256 _indicator
  ) internal virtual;

  /**
   * @dev See `ICreditScore-CreditScoreConfigsUpdated`.
   */
  function _setCreditScoreConfigs(
    uint256 _gainCreditScore,
    uint256 _maxCreditScore,
    uint256 _bailOutCostMultiplier,
    uint256 _cutOffPercentageAfterBailout
  ) internal {
    require(_gainCreditScore <= _maxCreditScore, "CreditScore: invalid credit score config");
    require(_cutOffPercentageAfterBailout <= _MAX_PERCENTAGE, "CreditScore: invalid cut off percentage config");

    gainCreditScore = _gainCreditScore;
    maxCreditScore = _maxCreditScore;
    bailOutCostMultiplier = _bailOutCostMultiplier;
    cutOffPercentageAfterBailout = _cutOffPercentageAfterBailout;
    emit CreditScoreConfigsUpdated(
      _gainCreditScore,
      _maxCreditScore,
      _bailOutCostMultiplier,
      _cutOffPercentageAfterBailout
    );
  }
}
