// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../../libraries/EnumFlags.sol";
import "../../../extensions/collections/HasRoninTrustedOrganizationContract.sol";
import "../../../interfaces/validator/info-fragments/IValidatorInfo.sol";

abstract contract ValidatorInfoStorage is IValidatorInfo, HasRoninTrustedOrganizationContract {
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
    uint256 _validatorCount = validatorCount;
    _validatorList = new address[](_validatorCount);
    _bridgeOperators = new address[](_validatorCount);
    _flags = new EnumFlags.ValidatorFlag[](_validatorCount);
    for (uint _i; _i < _validatorCount; ) {
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
    unchecked {
      address validator;
      for (uint _i; _i < _result.length; _i++) {
        validator = _validators[_i];
        if (isBlockProducer(validator)) {
          _result[_count++] = validator;
        }
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
  function totalBlockProducers() external view returns (uint256 _total) {
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
  function getBridgeOperators() public view override returns (address[] memory _result) {
    _result = new address[](validatorCount);
    uint256 _count;
    unchecked {
      for (uint _i; _i < _result.length; _i++) {
        if (isOperatingBridge(_validators[_i])) {
          _result[_count++] = _bridgeOperatorOf(_validators[_i]);
        }
      }
    }

    assembly {
      mstore(_result, _count)
    }
  }

  /**
   * @inheritdoc IValidatorInfo
   */
  function getBridgeOperatorsOf(address[] memory _validatorAddrs)
    public
    view
    override
    returns (address[] memory _result)
  {
    _result = new address[](_validatorAddrs.length);
    unchecked {
      for (uint _i; _i < _result.length; _i++) {
        _result[_i] = _bridgeOperatorOf(_validatorAddrs[_i]);
      }
    }
  }

  /**
   * @inheritdoc IValidatorInfo
   */
  function isBridgeOperator(address _bridgeOperatorAddr) external view override returns (bool _isOperator) {
    unchecked {
      for (uint _i; _i < validatorCount; _i++) {
        if (_bridgeOperatorOf(_validators[_i]) == _bridgeOperatorAddr && isOperatingBridge(_validators[_i])) {
          _isOperator = true;
          break;
        }
      }
    }
  }

  /**
   * @inheritdoc IValidatorInfo
   */
  function isOperatingBridge(address _consensusAddr) public view override returns (bool) {
    return _validatorMap[_consensusAddr].hasFlag(EnumFlags.ValidatorFlag.BridgeOperator);
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
  function totalBridgeOperators() public view returns (uint256 _total) {
    unchecked {
      uint256 _validatorCount = validatorCount;
      for (uint _i; _i < _validatorCount; ++_i) {
        if (isOperatingBridge(_validators[_i])) {
          ++_total;
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
    assembly {
      sstore(_maxValidatorNumber.slot, _number)
      mstore(0x00, _number)
      log1(
        0x00,
        0x20,
        /// @dev value is equal to keccak256("MaxValidatorNumberUpdated(uint256)")
        0xb5464c05fd0e0f000c535850116cda2742ee1f7b34384cb920ad7b8e802138b5
      )
    }
  }

  /**
   * @dev See `IValidatorInfo-setMaxPrioritizedValidatorNumber`
   */
  function _setMaxPrioritizedValidatorNumber(uint256 _number) internal {
    assembly {
      if gt(_number, sload(_maxValidatorNumber.slot)) {
        /// @dev value is equal to bytes4(keccak256("ErrInvalidMaxPrioritizedValidatorNumber()"))
        mstore(0x00, 0xaa8119d2)
        revert(0x1c, 0x04)
      }

      sstore(_maxPrioritizedValidatorNumber.slot, _number)
      mstore(0x00, _number)
      log1(
        0x00,
        0x20,
        /// @dev value is equal to keccak256("MaxPrioritizedValidatorNumberUpdated(uint256)")
        0xa9588dc77416849bd922605ce4fc806712281ad8a8f32d4238d6c8cca548e15e
      )
    }
  }
}
