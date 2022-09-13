// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/ISlashIndicator.sol";
import "../interfaces/IRoninValidatorSet.sol";

contract SlashIndicator is ISlashIndicator, Initializable {
  /// @dev Mapping from validator address => unavailability indicator
  mapping(address => uint256) internal _unavailabilityIndicator;
  /// @dev The last block that a validator is slashed
  uint256 public lastSlashedBlock;

  /// @dev The threshold to slash when validator is unavailability reaches misdemeanor
  uint256 public misdemeanorThreshold;
  /// @dev The threshold to slash when validator is unavailability reaches felony
  uint256 public felonyThreshold;

  /// @dev The amount of RON to slash felony.
  uint256 public slashFelonyAmount;
  /// @dev The amount of RON to slash double sign.
  uint256 public slashDoubleSignAmount;
  /// @dev The block duration to jail validator that reaches felony thresold.
  uint256 public felonyJailDuration;

  /// @dev The validator contract
  IRoninValidatorSet public validatorContract;
  /// @dev The governance admin
  address internal _governanceAdmin;

  modifier onlyCoinbase() {
    require(msg.sender == block.coinbase, "SlashIndicator: method caller is not the coinbase");
    _;
  }

  modifier onlyValidatorContract() {
    require(msg.sender == address(validatorContract), "SlashIndicator: method caller is not the validator contract");
    _;
  }

  modifier onlyGovernanceAdmin() {
    require(msg.sender == _governanceAdmin, "SlashIndicator: method caller is not the governance admin");
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
    uint256 _misdemeanorThreshold,
    uint256 _felonyThreshold,
    IRoninValidatorSet _validatorSetContract,
    uint256 _slashFelonyAmount,
    uint256 _slashDoubleSignAmount,
    uint256 _felonyJailBlocks
  ) external initializer {
    misdemeanorThreshold = _misdemeanorThreshold;
    felonyThreshold = _felonyThreshold;
    validatorContract = _validatorSetContract;
    slashFelonyAmount = _slashFelonyAmount;
    slashDoubleSignAmount = _slashDoubleSignAmount;
    felonyJailDuration = _felonyJailBlocks;
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                                SLASHING FUNCTIONS                                 //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc ISlashIndicator
   */
  function slash(address _validatorAddr) external override onlyCoinbase oncePerBlock {
    if (msg.sender == _validatorAddr) {
      return;
    }

    uint256 _count = ++_unavailabilityIndicator[_validatorAddr];

    // Slashes the validator as either the fenoly or the misdemeanor
    if (_count == felonyThreshold) {
      emit ValidatorSlashed(_validatorAddr, SlashType.FELONY);
      validatorContract.slash(_validatorAddr, block.number + felonyJailDuration, slashFelonyAmount);
    } else if (_count == misdemeanorThreshold) {
      emit ValidatorSlashed(_validatorAddr, SlashType.MISDEMEANOR);
      validatorContract.slash(_validatorAddr, 0, 0);
    }
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function slashDoubleSign(
    address _validatorAddr,
    bytes calldata /* _evidence */
  ) external override onlyCoinbase {
    bool _proved = false; // Proves the `_evidence` is right
    if (_proved) {
      validatorContract.slash(_validatorAddr, type(uint256).max, slashDoubleSignAmount);
    }
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function resetCounters(address[] calldata _validatorAddrs) external override onlyValidatorContract {
    _resetCounters(_validatorAddrs);
  }

  /**
   * @dev Resets counter for the validator address.
   */
  function _resetCounters(address[] calldata _validatorAddrs) private {
    if (_validatorAddrs.length == 0) {
      return;
    }

    for (uint _i = 0; _i < _validatorAddrs.length; _i++) {
      delete _unavailabilityIndicator[_validatorAddrs[_i]];
    }
    emit UnavailabilityIndicatorsReset(_validatorAddrs);
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                               GOVERNANCE FUNCTIONS                                //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc ISlashIndicator
   */
  function setSlashThresholds(uint256 _felonyThreshold, uint256 _misdemeanorThreshold)
    external
    override
    onlyGovernanceAdmin
  {
    felonyThreshold = _felonyThreshold;
    misdemeanorThreshold = _misdemeanorThreshold;
    emit SlashThresholdsUpdated(_felonyThreshold, _misdemeanorThreshold);
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function setSlashFelonyAmount(uint256 _slashFelonyAmount) external override onlyGovernanceAdmin {
    slashFelonyAmount = _slashFelonyAmount;
    emit SlashFelonyAmountUpdated(_slashFelonyAmount);
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function setSlashDoubleSignAmount(uint256 _slashDoubleSignAmount) external override onlyGovernanceAdmin {
    slashDoubleSignAmount = _slashDoubleSignAmount;
    emit SlashDoubleSignAmountUpdated(_slashDoubleSignAmount);
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function setFelonyJailDuration(uint256 _felonyJailDuration) external override onlyGovernanceAdmin {
    felonyJailDuration = _felonyJailDuration;
    emit FelonyJailDurationUpdated(_felonyJailDuration);
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                                  QUERY FUNCTIONS                                  //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc ISlashIndicator
   */
  function getSlashIndicator(address validator) external view override returns (uint256) {
    return _unavailabilityIndicator[validator];
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function getSlashThresholds() external view override returns (uint256, uint256) {
    return (misdemeanorThreshold, felonyThreshold);
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function governanceAdmin() external view override returns (address) {
    return _governanceAdmin;
  }
}
