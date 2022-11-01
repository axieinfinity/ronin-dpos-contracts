// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../interfaces/ICreditScore.sol";
import "../../extensions/collections/HasMaintenanceContract.sol";
import "../../extensions/collections/HasValidatorContract.sol";
import "../../libraries/Math.sol";

abstract contract CreditScore is ICreditScore, HasValidatorContract, HasMaintenanceContract {
  /// @dev Mapping from validator address => period index => whether bailed out before
  mapping(address => mapping(uint256 => bool)) internal _bailedOutStatus;
  /// @dev Mapping from validator address => credit score
  mapping(address => uint256) internal _creditScore;

  /// @dev The max gained number of credit score per period.
  uint256 public gainCreditScore;
  /// @dev The max number of credit score that a validator can hold.
  uint256 public maxCreditScore;
  /// @dev The number that will be multiplied with the remaining jailed time to get the cost of bailing out.
  uint256 public bailOutCostMultiplier;

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
    require(!_bailedOutStatus[_consensusAddr][_period], "SlashIndicator: validator has bailed out previously");

    uint256 _score = _creditScore[_consensusAddr];
    uint256 _cost = _jailedEpochLeft * bailOutCostMultiplier;
    require(_score >= _cost, "SlashIndicator: insufficient credit score to bail out");

    _validatorContract.bailOut(_consensusAddr);

    _creditScore[_consensusAddr] -= _cost;
    _setUnavailabilityIndicator(_consensusAddr, _period, 0);
    _bailedOutStatus[_consensusAddr][_period] = true;

    // TODO: - Remove all rewards of the validator before the bailout
    // TODO: - After the bailout, the validator gets 50% of the rewards until the end of the period.
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                               GOVERNANCE FUNCTIONS                                //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev See `ICreditScore`.
   */
  function setCreditScoreConfigs(
    uint256 _gainCreditScore,
    uint256 _maxCreditScore,
    uint256 _bailOutCostMultiplier
  ) external override onlyAdmin {
    _setCreditScoreConfigs(_gainCreditScore, _maxCreditScore, _bailOutCostMultiplier);
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                                  QUERY FUNCTIONS                                  //
  ///////////////////////////////////////////////////////////////////////////////////////

  function getUnavailabilityIndicator(address _validator, uint256 _period) public view virtual returns (uint256);

  /**
   * @dev See `ICreditScore`.
   */
  function getCreditScoreConfigs()
    external
    view
    override
    returns (
      uint256 _gainCreditScore,
      uint256 _maxCreditScore,
      uint256 _bailOutCostMultiplier
    )
  {
    _gainCreditScore = gainCreditScore;
    _maxCreditScore = maxCreditScore;
    _bailOutCostMultiplier = bailOutCostMultiplier;
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

  ///////////////////////////////////////////////////////////////////////////////////////
  //                                 HELPER FUNCTIONS                                  //
  ///////////////////////////////////////////////////////////////////////////////////////

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
    uint256 _bailOutCostMultiplier
  ) internal {
    require(_gainCreditScore <= _maxCreditScore, "CreditScore: invalid credit score config");

    gainCreditScore = _gainCreditScore;
    maxCreditScore = _maxCreditScore;
    bailOutCostMultiplier = _bailOutCostMultiplier;
    emit CreditScoreConfigsUpdated(_gainCreditScore, _maxCreditScore, _bailOutCostMultiplier);
  }
}
