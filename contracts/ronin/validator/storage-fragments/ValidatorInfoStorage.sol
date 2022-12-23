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
  function getValidators() public view override returns (address[] memory _validatorList) {
    _validatorList = new address[](validatorCount);
    for (uint _i = 0; _i < _validatorList.length; _i++) {
      _validatorList[_i] = _validators[_i];
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
    for (uint _i = 0; _i < _result.length; _i++) {
      if (isBlockProducer(_validators[_i])) {
        _result[_count++] = _validators[_i];
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
    for (uint _i = 0; _i < validatorCount; _i++) {
      if (isBlockProducer(_validators[_i])) {
        _total++;
      }
    }
  }

  /**
   * @inheritdoc IValidatorInfo
   */
  function getBridgeOperators() public view override returns (address[] memory _result) {
    _result = new address[](validatorCount);
    uint256 _count = 0;
    for (uint _i = 0; _i < _result.length; _i++) {
      if (isBlockProducer(_validators[_i])) {
        _result[_count++] = _bridgeOperatorOf(_validators[_i]);
      }
    }

    assembly {
      mstore(_result, _count)
    }
  }

  /**
   * @inheritdoc IValidatorInfo
   */
  function isBridgeOperator(address _bridgeOperatorAddr) external view override returns (bool _result) {
    for (uint _i = 0; _i < validatorCount; _i++) {
      if (_bridgeOperatorOf(_validators[_i]) == _bridgeOperatorAddr && isOperatingBridge(_validators[_i])) {
        _result = true;
        break;
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
    for (uint _i = 0; _i < validatorCount; _i++) {
      if (isOperatingBridge(_validators[_i])) {
        _total++;
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
    require(
      _number <= _maxValidatorNumber,
      "RoninValidatorSet: cannot set number of prioritized greater than number of max validators"
    );

    _maxPrioritizedValidatorNumber = _number;
    emit MaxPrioritizedValidatorNumberUpdated(_number);
  }
}
