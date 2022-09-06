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
  mapping(address => uint256) internal _unavailabilityIndicator;
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
    if (msg.sender == _validatorAddr) {
      return;
    }

    uint256 _count = ++_unavailabilityIndicator[_validatorAddr];

    // Slashs the validator as either the fenoly or the misdemeanor
    if (_count == felonyThreshold) {
      validatorContract.slashFelony(_validatorAddr);
      emit ValidatorSlashed(_validatorAddr, SlashType.FELONY);
    } else if (_count == misdemeanorThreshold) {
      validatorContract.slashMisdemeanor(_validatorAddr);
      emit ValidatorSlashed(_validatorAddr, SlashType.MISDEMAENOR);
    }
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function resetCounters(address[] calldata _validatorAddrs) external override onlyValidatorContract {
    _resetCounters(_validatorAddrs);
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
}
