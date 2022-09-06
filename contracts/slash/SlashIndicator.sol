// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../interfaces/ISlashIndicator.sol";
import "../interfaces/IStaking.sol";
import "../interfaces/IRoninValidatorSet.sol";

/**
 * TODO: Apply proxy pattern to this contract.
 */
contract SlashIndicator is ISlashIndicator {
  /// @dev Mapping from validator address => unavailability indicator
  mapping(address => Indicator) internal _unavailabilityIndicator;
  /// @dev The last block that a validator is slashed
  uint256 public lastSlashedBlock;

  /// @dev The threshold to slash when validator is unavailability reaches misdemeanor
  uint256 public misdemeanorThreshold; // TODO: add setter by gov admin
  /// @dev The threshold to slash when validator is unavailability reaches felony
  uint256 public felonyThreshold; // TODO: add setter by gov admin
  /// @dev The validator contract
  IRoninValidatorSet public validatorContract;

  modifier onlyCoinbase() {
    require(msg.sender == block.coinbase, "SlashIndicator: method caller is not the coinbase");
    _;
  }

  modifier onlyValidatorContract() {
    require(msg.sender == address(validatorContract), "SlashIndicator: method caller is not the validator contract");
    _;
  }

  modifier oncePerBlock() {
    require(block.number > lastSlashedBlock, "SlashIndicator: cannot slash twice in one block");
    _;
    lastSlashedBlock = block.number;
  }

  constructor(IRoninValidatorSet _validatorSetContract) {
    misdemeanorThreshold = 50;
    felonyThreshold = 150;
    validatorContract = _validatorSetContract;
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function slash(address _validatorAddr) external override onlyCoinbase oncePerBlock {
    Indicator storage indicator = _unavailabilityIndicator[_validatorAddr];
    indicator.counter++;
    indicator.lastSyncedBlock = block.number;

    // Slashs the validator as either the fenoly or the misdemeanor
    if (indicator.counter == felonyThreshold) {
      validatorContract.slashFelony(_validatorAddr);
      emit ValidatorSlashed(_validatorAddr, SlashType.FELONY);
    } else if (indicator.counter == misdemeanorThreshold) {
      validatorContract.slashMisdemeanor(_validatorAddr);
      emit ValidatorSlashed(_validatorAddr, SlashType.MISDEMAENOR);
    }
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function resetCounters(address[] calldata _validatorAddrs) external override onlyValidatorContract {
    if (_validatorAddrs.length == 0) {
      return;
    }

    for (uint256 _i; _i < _validatorAddrs.length; _i++) {
      _resetCounter(_validatorAddrs[_i]);
    }
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function resetCounter(address _validatorAddr) external override onlyValidatorContract {
    _resetCounter(_validatorAddr);
    emit UnavailabilityIndicatorReset(_validatorAddr);
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function slashDoubleSign(address _valAddr, bytes calldata _evidence) external override onlyCoinbase {
    revert("Not implemented");
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function getSlashIndicator(address validator) external view override returns (Indicator memory _indicator) {
    _indicator = _unavailabilityIndicator[validator];
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function getSlashThresholds() external view override returns (uint256, uint256) {
    return (misdemeanorThreshold, felonyThreshold);
  }

  /**
   * @dev Resets counter for the validator address.
   */
  function _resetCounter(address _validatorAddr) private {
    Indicator storage _indicator = _unavailabilityIndicator[_validatorAddr];
    _indicator.counter = 0;
    _indicator.lastSyncedBlock = block.number;
  }
}
