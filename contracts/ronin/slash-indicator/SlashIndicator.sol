// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../interfaces/slash-indicator/ISlashIndicator.sol";
import "../../interfaces/validator/IRoninValidatorSet.sol";
import "../../interfaces/IMaintenance.sol";
import "./SlashDoubleSign.sol";
import "./SlashFastFinality.sol";
import "./SlashBridgeVoting.sol";
import "./SlashBridgeOperator.sol";
import "./SlashUnavailability.sol";
import "./CreditScore.sol";

contract SlashIndicator is
  ISlashIndicator,
  SlashDoubleSign,
  SlashFastFinality,
  SlashBridgeVoting,
  SlashBridgeOperator,
  SlashUnavailability,
  CreditScore,
  Initializable
{
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(
    address __validatorContract,
    address __maintenanceContract,
    address __roninTrustedOrganizationContract,
    address __roninGovernanceAdminContract,
    // _bridgeOperatorSlashingConfigs[0]: _missingVotesRatioTier1
    // _bridgeOperatorSlashingConfigs[1]: _missingVotesRatioTier2
    // _bridgeOperatorSlashingConfigs[2]: _jailDurationForMissingVotesRatioTier2
    // _bridgeOperatorSlashingConfigs[3]: _skipBridgeOperatorSlashingThreshold
    uint256[4] calldata _bridgeOperatorSlashingConfigs,
    // _bridgeVotingSlashingConfigs[0]: _bridgeVotingThreshold
    // _bridgeVotingSlashingConfigs[1]: _bridgeVotingSlashAmount
    uint256[2] calldata _bridgeVotingSlashingConfigs,
    // _doubleSignSlashingConfigs[0]: _slashDoubleSignAmount
    // _doubleSignSlashingConfigs[1]: _doubleSigningJailUntilBlock
    // _doubleSignSlashingConfigs[2]: _doubleSigningOffsetLimitBlock
    uint256[3] calldata _doubleSignSlashingConfigs,
    // _unavailabilitySlashingConfigs[0]: _unavailabilityTier1Threshold
    // _unavailabilitySlashingConfigs[1]: _unavailabilityTier2Threshold
    // _unavailabilitySlashingConfigs[2]: _slashAmountForUnavailabilityTier2Threshold
    // _unavailabilitySlashingConfigs[3]: _jailDurationForUnavailabilityTier2Threshold
    uint256[4] calldata _unavailabilitySlashingConfigs,
    // _creditScoreConfigs[0]: _gainCreditScore
    // _creditScoreConfigs[1]: _maxCreditScore
    // _creditScoreConfigs[2]: _bailOutCostMultiplier
    // _creditScoreConfigs[3]: _cutOffPercentageAfterBailout
    uint256[4] calldata _creditScoreConfigs
  ) external initializer {
    _setContract(ContractType.VALIDATOR, __validatorContract);
    _setContract(ContractType.MAINTENANCE, __maintenanceContract);
    _setContract(ContractType.GOVERNANCE_ADMIN, __roninGovernanceAdminContract);
    _setContract(ContractType.RONIN_TRUSTED_ORGANIZATION, __roninTrustedOrganizationContract);

    _setBridgeOperatorSlashingConfigs(
      _bridgeOperatorSlashingConfigs[0],
      _bridgeOperatorSlashingConfigs[1],
      _bridgeOperatorSlashingConfigs[2],
      _bridgeOperatorSlashingConfigs[3]
    );
    _setBridgeVotingSlashingConfigs(_bridgeVotingSlashingConfigs[0], _bridgeVotingSlashingConfigs[1]);
    _setDoubleSignSlashingConfigs(
      _doubleSignSlashingConfigs[0],
      _doubleSignSlashingConfigs[1],
      _doubleSignSlashingConfigs[2]
    );
    _setUnavailabilitySlashingConfigs(
      _unavailabilitySlashingConfigs[0],
      _unavailabilitySlashingConfigs[1],
      _unavailabilitySlashingConfigs[2],
      _unavailabilitySlashingConfigs[3]
    );
    _setCreditScoreConfigs(
      _creditScoreConfigs[0],
      _creditScoreConfigs[1],
      _creditScoreConfigs[2],
      _creditScoreConfigs[3]
    );
  }

  function initializeV2(address roninGovernanceAdminContract) external reinitializer(2) {
    _setContract(ContractType.VALIDATOR, ______deprecatedValidator);
    _setContract(ContractType.MAINTENANCE, ______deprecatedMaintenance);
    _setContract(ContractType.GOVERNANCE_ADMIN, roninGovernanceAdminContract);
    _setContract(ContractType.RONIN_TRUSTED_ORGANIZATION, ______deprecatedTrustedOrg);

    delete ______deprecatedValidator;
    delete ______deprecatedMaintenance;
    delete ______deprecatedTrustedOrg;
    delete ______deprecatedGovernanceAdmin;
  }

  function initializeV3(address profileContract) external reinitializer(3) {
    _setContract(ContractType.PROFILE, profileContract);
    _setFastFinalitySlashingConfigs(_slashDoubleSignAmount, _doubleSigningJailUntilBlock);
  }

  /**
   * @dev Helper for CreditScore contract to reset the indicator of the validator after bailing out.
   */
  function _setUnavailabilityIndicator(
    address _validator,
    uint256 _period,
    uint256 _indicator
  ) internal override(CreditScore, SlashUnavailability) {
    SlashUnavailability._setUnavailabilityIndicator(_validator, _period, _indicator);
  }

  /**
   * @dev Helper for CreditScore contract to query indicator of the validator.
   */
  function getUnavailabilityIndicator(
    address _validator,
    uint256 _period
  ) public view override(CreditScore, ISlashUnavailability, SlashUnavailability) returns (uint256) {
    return SlashUnavailability.getUnavailabilityIndicator(_validator, _period);
  }

  /**
   * @inheritdoc ICreditScore
   */
  function checkBailedOutAtPeriod(
    address _validator,
    uint256 _period
  ) public view override(CreditScore, ICreditScore, SlashUnavailability) returns (bool) {
    return CreditScore.checkBailedOutAtPeriod(_validator, _period);
  }

  /**
   * @dev Sanity check the address to be slashed
   */
  function _shouldSlash(address _addr) internal view override(SlashDoubleSign, SlashUnavailability) returns (bool) {
    return
      (msg.sender != _addr) &&
      IRoninValidatorSet(getContract(ContractType.VALIDATOR)).isBlockProducer(_addr) &&
      !IMaintenance(getContract(ContractType.MAINTENANCE)).checkMaintained(_addr, block.number);
  }
}
