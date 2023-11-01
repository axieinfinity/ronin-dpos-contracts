// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../interfaces/IMaintenance.sol";
import "../../interfaces/validator/IRoninValidatorSet.sol";
import "../../interfaces/slash-indicator/ICreditScore.sol";
import "../../extensions/collections/HasContracts.sol";
import "../../extensions/consumers/PercentageConsumer.sol";
import "../../libraries/Math.sol";
import "forge-std/console2.sol";
import { HasValidatorDeprecated, HasMaintenanceDeprecated } from "../../utils/DeprecatedSlots.sol";
import { ErrUnauthorized, RoleAccess } from "../../utils/CommonErrors.sol";

abstract contract CreditScore is
  ICreditScore,
  HasContracts,
  HasValidatorDeprecated,
  HasMaintenanceDeprecated,
  PercentageConsumer
{
  /// @dev Mapping from validator id => period index => whether bailed out before
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
  function execUpdateCreditScores(
    address[] calldata validatorIds,
    uint256 period
  ) external override onlyContract(ContractType.VALIDATOR) {
    IRoninValidatorSet validatorContract = IRoninValidatorSet(msg.sender);
    uint256 periodStartAtBlock = validatorContract.currentPeriodStartAtBlock();
    bool[] memory jaileds = validatorContract.checkManyJailedById(validatorIds);
    bool[] memory maintaineds = IMaintenance(getContract(ContractType.MAINTENANCE)).checkManyMaintainedInBlockRangeById(
      validatorIds,
      periodStartAtBlock,
      block.number
    );
    uint256[] memory updatedCreditScores = new uint256[](validatorIds.length);

    for (uint i = 0; i < validatorIds.length; ) {
      address vId = validatorIds[i];

      uint256 indicator = _getUnavailabilityIndicatorById(vId, period);
      bool isJailedInPeriod = jaileds[i];
      bool isMaintainingInPeriod = maintaineds[i];

      uint256 _actualGain = (isJailedInPeriod || isMaintainingInPeriod)
        ? 0
        : Math.subNonNegative(_gainCreditScore, indicator);

      _creditScore[vId] = Math.addWithUpperbound(_creditScore[vId], _actualGain, _maxCreditScore);
      updatedCreditScores[i] = _creditScore[vId];
      unchecked {
        ++i;
      }
    }

    emit CreditScoresUpdated(validatorIds, updatedCreditScores);
  }

  function execResetCreditScores(
    address[] calldata validatorIds
  ) external override onlyContract(ContractType.VALIDATOR) {
    uint256[] memory updatedCreditScores = new uint256[](validatorIds.length);
    for (uint i = 0; i < validatorIds.length; ) {
      address _validator = validatorIds[i];
      delete _creditScore[_validator];
      delete updatedCreditScores[i];

      unchecked {
        ++i;
      }
    }
    emit CreditScoresUpdated(validatorIds, updatedCreditScores);
  }

  /**
   * @inheritdoc ICreditScore
   */
  function bailOut(TConsensus consensusAddr) external override {
    address validatorId = _convertC2P(consensusAddr);
    IRoninValidatorSet validatorContract = IRoninValidatorSet(getContract(ContractType.VALIDATOR));
    if (!validatorContract.isValidatorCandidate(consensusAddr))
      revert ErrUnauthorized(msg.sig, RoleAccess.VALIDATOR_CANDIDATE);

    if (!validatorContract.isCandidateAdmin(consensusAddr, msg.sender))
      revert ErrUnauthorized(msg.sig, RoleAccess.CANDIDATE_ADMIN);

    (bool isJailed, , uint256 jailedEpochLeft) = validatorContract.getJailedTimeLeft(consensusAddr);
    if (!isJailed) revert ErrCallerMustBeJailedInTheCurrentPeriod();

    uint256 period = validatorContract.currentPeriod();
    if (_checkBailedOutAtPeriod[validatorId][period]) revert ErrValidatorHasBailedOutPreviously();

    uint256 score = _creditScore[validatorId];
    uint256 cost = jailedEpochLeft * _bailOutCostMultiplier;
    if (score < cost) revert ErrInsufficientCreditScoreToBailOut();

    validatorContract.execBailOut(validatorId, period);

    _creditScore[validatorId] -= cost;
    _setUnavailabilityIndicator(validatorId, period, 0);
    _checkBailedOutAtPeriod[validatorId][period] = true;
    emit BailedOut(consensusAddr, period, cost);
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
  function _getUnavailabilityIndicatorById(address validator, uint256 period) internal view virtual returns (uint256);

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
  function getCreditScore(TConsensus consensusAddr) external view override returns (uint256) {
    return _creditScore[_convertC2P(consensusAddr)];
  }

  /**
   * @inheritdoc ICreditScore
   */
  function getManyCreditScores(
    TConsensus[] calldata consensusAddrs
  ) public view override returns (uint256[] memory resultList) {
    address[] memory validatorIds = _convertManyC2P(consensusAddrs);
    resultList = new uint256[](validatorIds.length);

    for (uint i = 0; i < resultList.length; ) {
      resultList[i] = _creditScore[validatorIds[i]];

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @inheritdoc ICreditScore
   */
  function checkBailedOutAtPeriod(TConsensus consensus, uint256 period) external view override returns (bool) {
    return _checkBailedOutAtPeriodById(_convertC2P(consensus), period);
  }

  function _checkBailedOutAtPeriodById(address validatorId, uint256 period) internal view virtual returns (bool) {
    return _checkBailedOutAtPeriod[validatorId][period];
  }

  /**
   * @dev See `SlashUnavailability`.
   */
  function _setUnavailabilityIndicator(address _validator, uint256 period, uint256 _indicator) internal virtual;

  function _convertC2P(TConsensus consensusAddr) internal view virtual returns (address);

  function _convertManyC2P(TConsensus[] memory consensusAddrs) internal view virtual returns (address[] memory);

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
