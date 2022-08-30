// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./interfaces/ISlashIndicator.sol";
import "./interfaces/IStaking.sol";
import "./interfaces/IValidatorSet.sol";

contract SlashIndicator is ISlashIndicator {
  enum SlashType {
    UNKNOWN,
    MISDEMAENOR,
    FELONY,
    DOUBLE_SIGNING
  }

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
  event ResetIndicators();
  
  modifier onlyCoinbase() {
    require(msg.sender == block.coinbase, "Only coinbase");
    _;
  }

  modifier onlyValidatorContract() {
    require(msg.sender == address(validatorSetContract), "Only validator set contract");
    _;
  }

  modifier oncePerBlock() {
    require(block.number > previousHeight, "Cannot slash twice in one block");
    _;
    previousHeight = block.number;
  }

  modifier onlyInitialized() {
    require(initialized, "Contract is not initialized");
    _;
  }

  constructor () {
    misdemeanorThreshold = MISDEMEANOR_THRESHOLD;
    felonyThreshold = FELONY_THRESHOLD;
  }

  function initialize(IValidatorSet _validatorSetContract, IStaking _stakingContract) external {
    require(!initialized, "Contract is already initialized");

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
  function slash(address _validatorAddr) external onlyInitialized onlyCoinbase oncePerBlock {
    // Check if the to be slashed validator is in the current epoch 
    require(validatorSetContract.isCurrentValidator(_validatorAddr), "Cannot slash validator not in current epoch");

    Indicator storage indicator = indicators[_validatorAddr];
    
    // Add the validator to the list if they are not exist yet
    if (indicator.historicalCounter == 0) {
      indicator.historicalCounter = 1;
      indicator.counter = 1;
      validators.push(_validatorAddr);
    } else {
      indicator.historicalCounter++;
      indicator.counter++;
    }
    
    indicator.height = block.number;

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
  function resetCounters() external onlyInitialized onlyValidatorContract {
    if (validators.length == 0) {
      return;
    }

    for (uint i = 0; i < validators.length; i++) {
      Indicator storage _indicator = indicators[validators[i]];
      _indicator.counter = 0;
    }

    emit ResetIndicators();
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
  function slashDoubleSign(address valAddr, bytes calldata evidence) external onlyInitialized onlyCoinbase {
    revert("Not implemented");
  }

  /**
   * @notice Get slash indicator of a validator
   */
  function getSlashIndicator(address validator) external view returns (Indicator memory) {
    Indicator memory _indicator = indicators[validator];
    return _indicator; 
  }

  /**
   * @notice Get all validators which have slash information
   */
  function getSlashValidators() external view returns (address[] memory) {
    return validators;
  }

  function getSlashThresholds() external view returns (uint256, uint256) {
    return (misdemeanorThreshold, felonyThreshold);
  }
}
