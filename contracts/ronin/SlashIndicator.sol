// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/ISlashIndicator.sol";
import "../extensions/collections/HasValidatorContract.sol";
import "../extensions/collections/HasMaintenanceContract.sol";
import "../extensions/collections/HasRoninTrustedOrganizationContract.sol";
import "../extensions/collections/HasRoninGovernanceAdminContract.sol";
import "../libraries/Math.sol";
import "../precompile-usages/PrecompileUsageValidateDoubleSign.sol";

contract SlashIndicator is
  ISlashIndicator,
  PrecompileUsageValidateDoubleSign,
  HasValidatorContract,
  HasMaintenanceContract,
  HasRoninTrustedOrganizationContract,
  HasRoninGovernanceAdminContract,
  Initializable
{
  using Math for uint256;

  /// @dev Mapping from validator address => period index => unavailability indicator
  mapping(address => mapping(uint256 => uint256)) internal _unavailabilityIndicator;
  /// @dev Mapping from validator address => period index => bridge voting slashed
  mapping(address => mapping(uint256 => bool)) internal _bridgeVotingSlashed;
  /// @dev Mapping from validator address => period index => whether bailed out before
  mapping(address => mapping(uint256 => bool)) internal _bailedOutStatus;
  /// @dev Mapping from validator address => credit score
  mapping(address => uint256) internal _creditScore;

  /// @dev The last block that a validator is slashed
  uint256 public lastSlashedBlock;

  /// @dev The number of blocks that the current block can be ahead of the double signed blocks
  uint256 public doubleSigningConstrainBlocks;

  /// @dev The threshold to slash when validator is unavailability reaches misdemeanor
  uint256 public misdemeanorThreshold;
  /// @dev The threshold to slash when validator is unavailability reaches felony
  uint256 public felonyThreshold;
  /// @dev The threshold to slash when a trusted organization does not vote for bridge operators
  uint256 public bridgeVotingThreshold;

  /// @dev The amount of RON to slash felony.
  uint256 public slashFelonyAmount;
  /// @dev The amount of RON to slash double sign.
  uint256 public slashDoubleSignAmount;
  /// @dev The amount of RON to slash bridge voting.
  uint256 public bridgeVotingSlashAmount;
  /// @dev The block duration to jail a validator that reaches felony thresold.
  uint256 public felonyJailDuration;
  /// @dev The block number that the punished validator will be jailed until, due to double signing.
  uint256 public doubleSigningJailUntilBlock;

  /// @dev The max gained number of credit score per period.
  uint256 public gainCreditScore;
  /// @dev The max number of credit score that a validator can hold.
  uint256 public maxCreditScore;
  /// @dev The number that will be multiplied with the remaining jailed time to get the cost of bailing out.
  uint256 public bailOutCostMultiplier;

  modifier onlyCoinbase() {
    require(msg.sender == block.coinbase, "SlashIndicator: method caller must be coinbase");
    _;
  }

  modifier oncePerBlock() {
    require(
      block.number > lastSlashedBlock,
      "SlashIndicator: cannot slash a validator twice or slash more than one validator in one block"
    );
    _;
    lastSlashedBlock = block.number;
  }

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
    uint256[3] calldata _thresholdConfigs,
    uint256[3] calldata _slashAmountConfigs,
    uint256 _felonyJailBlocks,
    uint256 _doubleSigningConstrainBlocks,
    uint256[2] calldata _creditScoreConfigs,
    uint256 _bailOutCostMultiplier
  ) external initializer {
    _setValidatorContract(__validatorContract);
    _setMaintenanceContract(__maintenanceContract);
    _setRoninTrustedOrganizationContract(__roninTrustedOrganizationContract);
    _setRoninGovernanceAdminContract(__roninGovernanceAdminContract);
    _setSlashThresholds(_thresholdConfigs[0], _thresholdConfigs[1]);
    _setBridgeVotingThreshold(_thresholdConfigs[2]);
    _setSlashFelonyAmount(_slashAmountConfigs[0]);
    _setSlashDoubleSignAmount(_slashAmountConfigs[1]);
    _setBridgeVotingSlashAmount(_slashAmountConfigs[2]);
    _setFelonyJailDuration(_felonyJailBlocks);
    _setDoubleSigningConstrainBlocks(_doubleSigningConstrainBlocks);
    _setDoubleSigningJailUntilBlock(type(uint256).max);
    _setGainCreditScore(_creditScoreConfigs[0]);
    _setMaxCreditScore(_creditScoreConfigs[1]);
    _setBailOutCostMultiplier(_bailOutCostMultiplier);
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                                SLASHING FUNCTIONS                                 //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc ISlashIndicator
   */
  function slash(address _validatorAddr) external override onlyCoinbase oncePerBlock {
    if (!_shouldSlash(_validatorAddr)) {
      return;
    }

    uint256 _period = _validatorContract.currentPeriod();
    uint256 _count = ++_unavailabilityIndicator[_validatorAddr][_period];

    if (_count == felonyThreshold) {
      emit UnavailabilitySlashed(_validatorAddr, SlashType.FELONY, _period);
      _validatorContract.slash(_validatorAddr, block.number + felonyJailDuration, slashFelonyAmount);
    } else if (_count == misdemeanorThreshold) {
      emit UnavailabilitySlashed(_validatorAddr, SlashType.MISDEMEANOR, _period);
      _validatorContract.slash(_validatorAddr, 0, 0);
    }
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function slashDoubleSign(
    address _validatorAddr,
    bytes calldata _header1,
    bytes calldata _header2
  ) external override onlyCoinbase oncePerBlock {
    if (!_shouldSlash(_validatorAddr)) {
      return;
    }

    if (_pcValidateEvidence(_header1, _header2)) {
      uint256 _period = _validatorContract.currentPeriod();
      emit UnavailabilitySlashed(_validatorAddr, SlashType.DOUBLE_SIGNING, _period);
      _validatorContract.slash(_validatorAddr, doubleSigningJailUntilBlock, slashDoubleSignAmount);
    }
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function slashBridgeVoting(address _consensusAddr) external {
    IRoninTrustedOrganization.TrustedOrganization memory _org = _roninTrustedOrganizationContract
      .getTrustedOrganization(_consensusAddr);
    uint256 _lastVotedBlock = Math.max(_roninGovernanceAdminContract.lastVotedBlock(_org.bridgeVoter), _org.addedBlock);
    uint256 _period = _validatorContract.currentPeriod();
    if (block.number - _lastVotedBlock > bridgeVotingThreshold && !_bridgeVotingSlashed[_consensusAddr][_period]) {
      _bridgeVotingSlashed[_consensusAddr][_period] = true;
      emit UnavailabilitySlashed(_consensusAddr, SlashType.BRIDGE_VOTING, _period);
      _validatorContract.slash(_consensusAddr, 0, bridgeVotingSlashAmount);
    }
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                              CREDIT SCORE FUNCTIONS                               //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc ISlashIndicator
   */
  function updateCreditScore(address[] calldata _validators, uint256 _period) external override onlyValidatorContract {
    bool[] memory _jaileds = _validatorContract.bulkJailed(_validators);
    bool[] memory _maintaineds = _maintenanceContract.bulkMaintainingAtCurrentPeriod(_validators);

    for (uint _i = 0; _i < _validators.length; _i++) {
      address _validator = _validators[_i];

      uint256 _indicator = _unavailabilityIndicator[_validator][_period];
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
    }

    emit CreditScoreUpdated(_validators);
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function bailOut() external override {
    require(_validatorContract.isValidator(msg.sender), "SlashIndicator: caller must be the validator");
    (bool _isJailed, , uint256 _jailedEpochLeft) = _validatorContract.jailedTimeLeft(msg.sender);
    require(_isJailed, "SlashIndicator: caller must be jailed in the current period");

    uint256 _period = _validatorContract.currentPeriod();
    require(!_bailedOutStatus[msg.sender][_period], "SlashIndicator: validator has bailed out previously");

    uint256 _score = _creditScore[msg.sender];
    uint256 _cost = _jailedEpochLeft * bailOutCostMultiplier;
    require(_score >= _cost, "SlashIndicator: insufficient credit score to bail out");

    _creditScore[msg.sender] -= _cost;
    _unavailabilityIndicator[msg.sender][_period] = 0;
    _bailedOutStatus[msg.sender][_period] = true;

    // TODO: - Remove all rewards of the validator before the bailout
    // TODO: - After the bailout, the validator gets 50% of the rewards until the end of the period.
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                               GOVERNANCE FUNCTIONS                                //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc ISlashIndicator
   */
  function setSlashThresholds(uint256 _misdemeanorThreshold, uint256 _felonyThreshold) external override onlyAdmin {
    _setSlashThresholds(_misdemeanorThreshold, _felonyThreshold);
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function setSlashFelonyAmount(uint256 _slashFelonyAmount) external override onlyAdmin {
    _setSlashFelonyAmount(_slashFelonyAmount);
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function setSlashDoubleSignAmount(uint256 _slashDoubleSignAmount) external override onlyAdmin {
    _setSlashDoubleSignAmount(_slashDoubleSignAmount);
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function setFelonyJailDuration(uint256 _felonyJailDuration) external override onlyAdmin {
    _setFelonyJailDuration(_felonyJailDuration);
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function setBridgeVotingThreshold(uint256 _threshold) external override onlyAdmin {
    _setBridgeVotingThreshold(_threshold);
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function setBridgeVotingSlashAmount(uint256 _amount) external override onlyAdmin {
    _setBridgeVotingSlashAmount(_amount);
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function setGainCreditScore(uint256 _gainCreditScore) external override onlyAdmin {
    _setGainCreditScore(_gainCreditScore);
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function setMaxCreditScore(uint256 _maxCreditScore) external override onlyAdmin {
    _setMaxCreditScore(_maxCreditScore);
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function setBailOutCostMultiplier(uint256 _bailOutCostMultiplier) external override onlyAdmin {
    _setBailOutCostMultiplier(_bailOutCostMultiplier);
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                                  QUERY FUNCTIONS                                  //
  ///////////////////////////////////////////////////////////////////////////////////////

  function currentUnavailabilityIndicator(address _validator) external view override returns (uint256) {
    return getUnavailabilityIndicator(_validator, _validatorContract.currentPeriod());
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function getUnavailabilityThresholds() external view override returns (uint256, uint256) {
    return (misdemeanorThreshold, felonyThreshold);
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function getUnavailabilityIndicator(address _validator, uint256 _period) public view override returns (uint256) {
    return _unavailabilityIndicator[_validator][_period];
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function getCreditScore(address _validator) public view override returns (uint256) {
    return _creditScore[_validator];
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                                 HELPER FUNCTIONS                                  //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Sets the slash thresholds
   */
  function _setSlashThresholds(uint256 _misdemeanorThreshold, uint256 _felonyThreshold) internal {
    misdemeanorThreshold = _misdemeanorThreshold;
    felonyThreshold = _felonyThreshold;
    emit SlashThresholdsUpdated(_misdemeanorThreshold, _felonyThreshold);
  }

  /**
   * @dev Sets the slash felony amount
   */
  function _setSlashFelonyAmount(uint256 _slashFelonyAmount) internal {
    slashFelonyAmount = _slashFelonyAmount;
    emit SlashFelonyAmountUpdated(_slashFelonyAmount);
  }

  /**
   * @dev Sets the slash double sign amount
   */
  function _setSlashDoubleSignAmount(uint256 _slashDoubleSignAmount) internal {
    slashDoubleSignAmount = _slashDoubleSignAmount;
    emit SlashDoubleSignAmountUpdated(_slashDoubleSignAmount);
  }

  /**
   * @dev Sets the felony jail duration
   */
  function _setFelonyJailDuration(uint256 _felonyJailDuration) internal {
    felonyJailDuration = _felonyJailDuration;
    emit FelonyJailDurationUpdated(_felonyJailDuration);
  }

  /**
   * @dev Sets the double signing constrain blocks
   */
  function _setDoubleSigningConstrainBlocks(uint256 _doubleSigningConstrainBlocks) internal {
    doubleSigningConstrainBlocks = _doubleSigningConstrainBlocks;
    emit DoubleSigningConstrainBlocksUpdated(_doubleSigningConstrainBlocks);
  }

  /**
   * @dev Sets the double signing jail until block number
   */
  function _setDoubleSigningJailUntilBlock(uint256 _doubleSigningJailUntilBlock) internal {
    doubleSigningJailUntilBlock = _doubleSigningJailUntilBlock;
    emit DoubleSigningJailUntilBlockUpdated(_doubleSigningJailUntilBlock);
  }

  /**
   * @dev Sets the threshold to slash when trusted organization does not vote for bridge operators.
   */
  function _setBridgeVotingThreshold(uint256 _threshold) internal {
    bridgeVotingThreshold = _threshold;
    emit BridgeVotingThresholdUpdated(_threshold);
  }

  /**
   * @dev Sets the amount of RON to slash bridge voting.
   */
  function _setBridgeVotingSlashAmount(uint256 _amount) internal {
    bridgeVotingSlashAmount = _amount;
    emit BridgeVotingSlashAmountUpdated(_amount);
  }

  function _setGainCreditScore(uint256 _gainCreditScore) internal {
    gainCreditScore = _gainCreditScore;
    emit GainCreditScoreUpdated(_gainCreditScore);
  }

  function _setMaxCreditScore(uint256 _maxCreditScore) internal {
    maxCreditScore = _maxCreditScore;
    emit MaxCreditScoreUpdated(_maxCreditScore);
  }

  function _setBailOutCostMultiplier(uint256 _bailOutCostMultiplier) internal {
    bailOutCostMultiplier = _bailOutCostMultiplier;
    emit BailOutCostMultiplierUpdated(_bailOutCostMultiplier);
  }

  /**
   * @dev Sanity check the address to be slashed
   */
  function _shouldSlash(address _addr) internal view returns (bool) {
    return
      (msg.sender != _addr) &&
      _validatorContract.isBlockProducer(_addr) &&
      !_maintenanceContract.maintaining(_addr, block.number);
  }
}
