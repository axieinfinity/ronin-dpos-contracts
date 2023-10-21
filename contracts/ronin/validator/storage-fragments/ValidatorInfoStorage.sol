// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../../libraries/EnumFlags.sol";
import { HasTrustedOrgDeprecated } from "../../../utils/DeprecatedSlots.sol";
import "../../../extensions/collections/HasContracts.sol";
import "../../../interfaces/validator/info-fragments/IValidatorInfo.sol";

abstract contract ValidatorInfoStorage is IValidatorInfo, HasContracts, HasTrustedOrgDeprecated {
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
   * @inheritdoc IValidatorInfo
   */
  function getValidators()
    public
    view
    override
    returns (
      address[] memory _validatorList,
      address[] memory _bridgeOperators,
      EnumFlags.ValidatorFlag[] memory _flags
    )
  {
    _validatorList = new address[](validatorCount);
    _bridgeOperators = new address[](validatorCount);
    _flags = new EnumFlags.ValidatorFlag[](validatorCount);
    for (uint _i; _i < _validatorList.length; ) {
      address _validator = _validators[_i];
      _validatorList[_i] = _validator;
      _bridgeOperators[_i] = _bridgeOperatorOf(_validator);
      _flags[_i] = _validatorMap[_validator];

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @inheritdoc IValidatorInfo
   */
  function isValidator(address _addr) public view override returns (bool) {
    return !_validatorMap[_addr].isNone();
  }

  /**
   * @inheritdoc IValidatorInfo
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
   * @inheritdoc IValidatorInfo
   */
  function isBlockProducer(address _addr) public view override returns (bool) {
    return _validatorMap[_addr].hasFlag(EnumFlags.ValidatorFlag.BlockProducer);
  }

  /**
   * @inheritdoc IValidatorInfo
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
   * @inheritdoc IValidatorInfo
   */
  function getBridgeOperators()
    public
    view
    override
    returns (address[] memory _bridgeOperatorList, address[] memory _validatorList)
  {
    uint256 _length = validatorCount;
    _bridgeOperatorList = new address[](_length);
    _validatorList = new address[](_length);
    uint256 _count = 0;
    unchecked {
      for (uint _i; _i < _length; ++_i) {
        if (isOperatingBridge(_validators[_i])) {
          address __validator = _validators[_i];
          _bridgeOperatorList[_count] = _bridgeOperatorOf(__validator);
          _validatorList[_count++] = __validator;
        }
      }
    }

    assembly {
      mstore(_bridgeOperatorList, _count)
      mstore(_validatorList, _count)
    }
  }

  /**
   * @inheritdoc IValidatorInfo
   */
  function getBridgeOperatorsOf(
    address[] memory _validatorAddrs
  ) public view override returns (address[] memory _bridgeOperatorList) {
    _bridgeOperatorList = new address[](_validatorAddrs.length);
    for (uint _i; _i < _bridgeOperatorList.length; ) {
      _bridgeOperatorList[_i] = _bridgeOperatorOf(_validatorAddrs[_i]);
      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @inheritdoc IValidatorInfo
   */
  function isBridgeOperator(address _bridgeOperatorAddr) external view override returns (bool _isOperator) {
    for (uint _i; _i < validatorCount; ) {
      if (_bridgeOperatorOf(_validators[_i]) == _bridgeOperatorAddr && isOperatingBridge(_validators[_i])) {
        _isOperator = true;
        break;
      }

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @inheritdoc IValidatorInfo
   */
  function isOperatingBridge(address _consensusAddr) public view override returns (bool) {
    return _validatorMap[_consensusAddr].hasFlag(EnumFlags.ValidatorFlag.DeprecatedBridgeOperator);
  }

  /**
   * @inheritdoc IValidatorInfo
   */
  function maxValidatorNumber() external view override returns (uint256 _maximumValidatorNumber) {
    return _maxValidatorNumber;
  }

  /**
   * @inheritdoc IValidatorInfo
   */
  function maxPrioritizedValidatorNumber() external view override returns (uint256 _maximumPrioritizedValidatorNumber) {
    return _maxPrioritizedValidatorNumber;
  }

  /**
   * @inheritdoc IValidatorInfo
   */
  function totalBridgeOperator() public view returns (uint256 _total) {
    unchecked {
      for (uint _i; _i < validatorCount; _i++) {
        if (isOperatingBridge(_validators[_i])) {
          _total++;
        }
      }
    }
  }

  /**
   * @inheritdoc IValidatorInfo
   */
  function setMaxValidatorNumber(uint256 _max) external override onlyAdmin {
    _setMaxValidatorNumber(_max);
  }

  /**
   * @inheritdoc IValidatorInfo
   */
  function setMaxPrioritizedValidatorNumber(uint256 _number) external override onlyAdmin {
    _setMaxPrioritizedValidatorNumber(_number);
  }

  /**
   * @dev Returns the bridge operator of a consensus address.
   */
  function _bridgeOperatorOf(address _consensusAddr) internal view virtual returns (address);

  /**
   * @dev See `IValidatorInfo-setMaxValidatorNumber`
   */
  function _setMaxValidatorNumber(uint256 _number) internal {
    _maxValidatorNumber = _number;
    emit MaxValidatorNumberUpdated(_number);
  }

  /**
   * @dev See `IValidatorInfo-setMaxPrioritizedValidatorNumber`
   */
  function _setMaxPrioritizedValidatorNumber(uint256 _number) internal {
    if (_number > _maxValidatorNumber) revert ErrInvalidMaxPrioritizedValidatorNumber();
    _maxPrioritizedValidatorNumber = _number;
    emit MaxPrioritizedValidatorNumberUpdated(_number);
  }
}
