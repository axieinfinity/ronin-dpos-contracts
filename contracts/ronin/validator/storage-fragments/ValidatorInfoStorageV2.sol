// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../../libraries/EnumFlags.sol";
import { HasTrustedOrgDeprecated } from "../../../utils/DeprecatedSlots.sol";
import "../../../extensions/collections/HasContracts.sol";
import "../../../interfaces/validator/info-fragments/IValidatorInfoV2.sol";

abstract contract ValidatorInfoStorageV2 is IValidatorInfoV2, HasContracts, HasTrustedOrgDeprecated {
  using EnumFlags for EnumFlags.ValidatorFlag;

  /// @dev The maximum number of validator.
  uint256 internal _maxValidatorNumber;

  /// @dev The total of validators
  uint256 public validatorCount;
  /// @dev Mapping from validator index => validator address
  mapping(uint256 => address) internal _validators;
  /// @dev Mapping from address => flag indicating the validator ability: producing block, operating bridge
  mapping(address => EnumFlags.ValidatorFlag) internal _validatorMap;
  /// @dev The number of slot that is reserved for prioritized validators
  uint256 internal _maxPrioritizedValidatorNumber;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private ______gap;

  /**
   * @inheritdoc IValidatorInfoV2
   */
  function getValidators() public view override returns (address[] memory _validatorList) {
    _validatorList = new address[](validatorCount);
    for (uint _i; _i < _validatorList.length; ) {
      address _validator = _validators[_i];
      _validatorList[_i] = _validator;

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @inheritdoc IValidatorInfoV2
   */
  function getBlockProducers() public view override returns (address[] memory _result) {
    _result = new address[](validatorCount);
    uint256 _count = 0;
    for (uint _i; _i < _result.length; ) {
      if (isBlockProducer(_validators[_i])) {
        _result[_count++] = _validators[_i];
      }

      unchecked {
        ++_i;
      }
    }

    assembly {
      mstore(_result, _count)
    }
  }

  /**
   * @inheritdoc IValidatorInfoV2
   */
  function isBlockProducer(address _addr) public view override returns (bool) {
    return _validatorMap[_addr].hasFlag(EnumFlags.ValidatorFlag.BlockProducer);
  }

  /**
   * @inheritdoc IValidatorInfoV2
   */
  function totalBlockProducer() external view returns (uint256 _total) {
    unchecked {
      for (uint _i; _i < validatorCount; _i++) {
        if (isBlockProducer(_validators[_i])) {
          _total++;
        }
      }
    }
  }

  /**
   * @inheritdoc IValidatorInfoV2
   */
  function maxValidatorNumber() external view override returns (uint256 _maximumValidatorNumber) {
    return _maxValidatorNumber;
  }

  /**
   * @inheritdoc IValidatorInfoV2
   */
  function maxPrioritizedValidatorNumber() external view override returns (uint256 _maximumPrioritizedValidatorNumber) {
    return _maxPrioritizedValidatorNumber;
  }

  /**
   * @inheritdoc IValidatorInfoV2
   */
  function setMaxValidatorNumber(uint256 _max) external override onlyAdmin {
    _setMaxValidatorNumber(_max);
  }

  /**
   * @inheritdoc IValidatorInfoV2
   */
  function setMaxPrioritizedValidatorNumber(uint256 _number) external override onlyAdmin {
    _setMaxPrioritizedValidatorNumber(_number);
  }

  /**
   * @dev See `IValidatorInfoV2-setMaxValidatorNumber`
   */
  function _setMaxValidatorNumber(uint256 _number) internal {
    _maxValidatorNumber = _number;
    emit MaxValidatorNumberUpdated(_number);
  }

  /**
   * @dev See `IValidatorInfoV2-setMaxPrioritizedValidatorNumber`
   */
  function _setMaxPrioritizedValidatorNumber(uint256 _number) internal {
    if (_number > _maxValidatorNumber) revert ErrInvalidMaxPrioritizedValidatorNumber();
    _maxPrioritizedValidatorNumber = _number;
    emit MaxPrioritizedValidatorNumberUpdated(_number);
  }
}
