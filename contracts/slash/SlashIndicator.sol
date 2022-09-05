// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../interfaces/ISlashIndicator.sol";
import "../interfaces/IStaking.sol";
import "../interfaces/IValidatorSet.sol";

contract SlashIndicator is ISlashIndicator {
  /// Init configuration
  uint256 public constant MISDEMEANOR_THRESHOLD = 50;
  uint256 public constant FELONY_THRESHOLD = 150;

  /// State of the contract
  bool public initialized;
  address[] public validators;
  mapping(address => Indicator) public indicators;
  uint256 public previousHeight;

  /// Threshold of slashing
  uint256 public misdemeanorThreshold;
  uint256 public felonyThreshold;

  /// Other contract address
  IValidatorSet public validatorSetContract;
  IStaking public stakingContract;

  event SlashedValidator(address indexed validator, SlashType slashType);
  event ResetIndicator(address indexed validator);
  event ResetIndicators();

  modifier onlyCoinbase() {
    require(msg.sender == block.coinbase, "Slash: Only coinbase");
    _;
  }

  modifier onlyValidatorContract() {
    require(msg.sender == address(validatorSetContract), "Slash: Only validator set contract");
    _;
  }

  modifier oncePerBlock() {
    require(block.number > previousHeight, "Slash: Cannot slash twice in one block");
    _;
    previousHeight = block.number;
  }

  modifier onlyInitialized() {
    require(initialized, "Slash: Contract is not initialized");
    _;
  }

  constructor() {
    misdemeanorThreshold = MISDEMEANOR_THRESHOLD;
    felonyThreshold = FELONY_THRESHOLD;
  }

  function initialize(IValidatorSet _validatorSetContract, IStaking _stakingContract) external {
    require(!initialized, "Slash: Contract is already initialized");

    initialized = true;
    validatorSetContract = _validatorSetContract;
    stakingContract = _stakingContract;
  }

  /**
   * @notice Slash for inavailability
   *
   * @dev Increase the counter of validator with valAddr. If the counter passes the threshold, call
   * the function from Validators.sol
   *
   * Requirements:
   * - Only coinbase can call this method
   *
   */
  function slash(address _validatorAddr) external override onlyInitialized onlyCoinbase oncePerBlock {
    // Check if the to be slashed validator is in the current epoch
    require(
      validatorSetContract.isCurrentValidator(_validatorAddr),
      "Slash: Cannot slash validator not in current epoch"
    );

    Indicator storage indicator = indicators[_validatorAddr];

    indicator.counter++;
    indicator.lastSyncedBlock = block.number;

    // Slash the validator as either the fenoly or the misdemeanor
    if (indicator.counter == felonyThreshold) {
      indicator.counter = 0;
      validatorSetContract.slashFelony(_validatorAddr);
      emit SlashedValidator(_validatorAddr, SlashType.FELONY);
    } else if (indicator.counter == misdemeanorThreshold) {
      validatorSetContract.slashMisdemeanor(_validatorAddr);
      emit SlashedValidator(_validatorAddr, SlashType.MISDEMAENOR);
    }
  }

  /**
   * @dev Reset the counter of the validator everyday
   *
   * Requirements:
   * - Only validator contract can call this method
   */
  function resetCounters(address[] calldata _validatorAddrs) external override onlyInitialized onlyValidatorContract {
    if (_validatorAddrs.length == 0) {
      return;
    }

    for (uint i = 0; i < _validatorAddrs.length; i++) {
      _resetCounter(_validatorAddrs[i]);
    }

    emit ResetIndicators();
  }

  function resetCounter(address _validatorAddr) external override onlyInitialized onlyValidatorContract {
    _resetCounter(_validatorAddr);
    emit ResetIndicator(_validatorAddr);
  }

  /**
   * @notice Slash for double signing
   *
   * @dev Verify the evidence, call the function from Validators.sol
   *
   * Requirements:
   * - Only coinbase can call this method
   *
   */
  function slashDoubleSign(address valAddr, bytes calldata evidence) external override onlyInitialized onlyCoinbase {
    revert("Not implemented");
  }

  /**
   * @notice Get slash indicator of a validator
   */
  function getSlashIndicator(address validator) external view override returns (Indicator memory) {
    Indicator memory _indicator = indicators[validator];
    return _indicator;
  }

  function getSlashThresholds() external view override returns (uint256, uint256) {
    return (misdemeanorThreshold, felonyThreshold);
  }

  function _resetCounter(address _validatorAddr) private {
    Indicator storage _indicator = indicators[_validatorAddr];
    _indicator.counter = 0;
    _indicator.lastSyncedBlock = block.number;
  }
}
