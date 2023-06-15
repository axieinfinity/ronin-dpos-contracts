// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../interfaces/IMaintenance.sol";
import "../../interfaces/validator/IRoninValidatorSet.sol";
import "../../interfaces/slash-indicator/ICreditScore.sol";
import "../../extensions/collections/HasContracts.sol";
import "../../extensions/consumers/PercentageConsumer.sol";
import "../../libraries/Math.sol";
import { HasValidatorDeprecated, HasMaintenanceDeprecated } from "../../utils/DeprecatedSlots.sol";
import { ErrUnauthorized, RoleAccess } from "../../utils/CommonErrors.sol";

abstract contract CreditScore is
  ICreditScore,
  HasContracts,
  HasValidatorDeprecated,
  HasMaintenanceDeprecated,
  PercentageConsumer
{
  /// @dev Mapping from validator address => period index => whether bailed out before
  mapping(address => mapping(uint256 => bool)) internal _checkBailedOutAtPeriod;
  /// @dev Mapping from validator address => credit score
  mapping(address => uint256) internal _creditScore;

  /// @dev The max gained number of credit score per period.
  uint256 internal _gainCreditScore;
  /// @dev The max number of credit score that a validator can hold.
  uint256 internal _maxCreditScore;
  /// @dev The number that will be multiplied with the remaining jailed time to get the cost of bailing out.
  uint256 internal _bailOutCostMultiplier;
  /// @dev The percentage of reward to be cut off from the validator in the rest of the period after bailed out.
  uint256 internal _cutOffPercentageAfterBailout;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private ______gap;

  /**
   * @inheritdoc ICreditScore
   */
  function updateCreditScores(
    address[] calldata _validators,
    uint256 _period
  ) external override onlyContract(ContractType.VALIDATOR) {
    IRoninValidatorSet _validatorContract = IRoninValidatorSet(msg.sender);
    uint256 _periodStartAtBlock = _validatorContract.currentPeriodStartAtBlock();

    bool[] memory _jaileds = _validatorContract.checkManyJailed(_validators);
    bool[] memory _maintaineds = IMaintenance(getContract(ContractType.MAINTENANCE)).checkManyMaintainedInBlockRange(
      _validators,
      _periodStartAtBlock,
      block.number
    );
    uint256[] memory _updatedCreditScores = new uint256[](_validators.length);

    for (uint _i = 0; _i < _validators.length; ) {
      address _validator = _validators[_i];

      uint256 _indicator = getUnavailabilityIndicator(_validator, _period);
      bool _isJailedInPeriod = _jaileds[_i];
      bool _isMaintainingInPeriod = _maintaineds[_i];

      uint256 _actualGain = (_isJailedInPeriod || _isMaintainingInPeriod)
        ? 0
        : Math.subNonNegative(_gainCreditScore, _indicator);

      _creditScore[_validator] = Math.addWithUpperbound(_creditScore[_validator], _actualGain, _maxCreditScore);
      _updatedCreditScores[_i] = _creditScore[_validator];
      unchecked {
        ++_i;
      }
    }

    emit CreditScoresUpdated(_validators, _updatedCreditScores);
  }

  function execResetCreditScores(
    address[] calldata _validators
  ) external override onlyContract(ContractType.VALIDATOR) {
    uint256[] memory _updatedCreditScores = new uint256[](_validators.length);
    for (uint _i = 0; _i < _validators.length; ) {
      address _validator = _validators[_i];
      delete _creditScore[_validator];
      delete _updatedCreditScores[_i];

      unchecked {
        ++_i;
      }
    }
    emit CreditScoresUpdated(_validators, _updatedCreditScores);
  }

  /**
   * @inheritdoc ICreditScore
   */
  function bailOut(address _consensusAddr) external override {
    IRoninValidatorSet _validatorContract = IRoninValidatorSet(getContract(ContractType.VALIDATOR));
    if (!_validatorContract.isValidatorCandidate(_consensusAddr))
      revert ErrUnauthorized(msg.sig, RoleAccess.VALIDATOR_CANDIDATE);

    if (!_validatorContract.isCandidateAdmin(_consensusAddr, msg.sender))
      revert ErrUnauthorized(msg.sig, RoleAccess.CANDIDATE_ADMIN);

    (bool _isJailed, , uint256 _jailedEpochLeft) = _validatorContract.getJailedTimeLeft(_consensusAddr);
    if (!_isJailed) revert ErrCallerMustBeJailedInTheCurrentPeriod();

    uint256 _period = _validatorContract.currentPeriod();
    if (_checkBailedOutAtPeriod[_consensusAddr][_period]) revert ErrValidatorHasBailedOutPreviously();

    uint256 _score = _creditScore[_consensusAddr];
    uint256 _cost = _jailedEpochLeft * _bailOutCostMultiplier;
    if (_score < _cost) revert ErrInsufficientCreditScoreToBailOut();

    _validatorContract.execBailOut(_consensusAddr, _period);

    _creditScore[_consensusAddr] -= _cost;
    _setUnavailabilityIndicator(_consensusAddr, _period, 0);
    _checkBailedOutAtPeriod[_consensusAddr][_period] = true;
    emit BailedOut(_consensusAddr, _period, _cost);
  }

  /**
   * @inheritdoc ICreditScore
   */
  function setCreditScoreConfigs(
    uint256 _gainScore,
    uint256 _maxScore,
    uint256 _bailOutMultiplier,
    uint256 _cutOffPercentage
  ) external override onlyAdmin {
    _setCreditScoreConfigs(_gainScore, _maxScore, _bailOutMultiplier, _cutOffPercentage);
  }

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
      uint256 gainCreditScore_,
      uint256 maxCreditScore_,
      uint256 bailOutCostMultiplier_,
      uint256 cutOffPercentageAfterBailout_
    )
  {
    return (_gainCreditScore, _maxCreditScore, _bailOutCostMultiplier, _cutOffPercentageAfterBailout);
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
  function getManyCreditScores(
    address[] calldata _validators
  ) public view override returns (uint256[] memory _resultList) {
    _resultList = new uint256[](_validators.length);

    for (uint _i = 0; _i < _resultList.length; ) {
      _resultList[_i] = _creditScore[_validators[_i]];

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @inheritdoc ICreditScore
   */
  function checkBailedOutAtPeriod(address _validator, uint256 _period) public view virtual override returns (bool) {
    return _checkBailedOutAtPeriod[_validator][_period];
  }

  /**
   * @dev See `SlashUnavailability`.
   */
  function _setUnavailabilityIndicator(address _validator, uint256 _period, uint256 _indicator) internal virtual;

  /**
   * @dev See `ICreditScore-setCreditScoreConfigs`.
   */
  function _setCreditScoreConfigs(
    uint256 _gainScore,
    uint256 _maxScore,
    uint256 _bailOutMultiplier,
    uint256 _cutOffPercentage
  ) internal {
    if (_gainScore > _maxScore) revert ErrInvalidCreditScoreConfig();
    if (_cutOffPercentage > _MAX_PERCENTAGE) revert ErrInvalidCutOffPercentageConfig();

    _gainCreditScore = _gainScore;
    _maxCreditScore = _maxScore;
    _bailOutCostMultiplier = _bailOutMultiplier;
    _cutOffPercentageAfterBailout = _cutOffPercentage;
    emit CreditScoreConfigsUpdated(_gainScore, _maxScore, _bailOutMultiplier, _cutOffPercentage);
  }
}
