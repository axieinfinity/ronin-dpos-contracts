// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../../libraries/EnumFlags.sol";
import "../../../extensions/collections/HasRoninTrustedOrganizationContract.sol";
import "../../../interfaces/validator/managers/IValidatorManager.sol";
import "./CandidateManager.sol";

abstract contract ValidatorManager is IValidatorManager, HasRoninTrustedOrganizationContract, CandidateManager {
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
   * @inheritdoc IValidatorManager
   */
  function getValidators() public view override returns (address[] memory _validatorList) {
    _validatorList = new address[](validatorCount);
    for (uint _i = 0; _i < _validatorList.length; _i++) {
      _validatorList[_i] = _validators[_i];
    }
  }

  /**
   * @inheritdoc IValidatorManager
   */
  function isValidator(address _addr) public view override returns (bool) {
    return !_validatorMap[_addr].isNone();
  }

  /**
   * @inheritdoc IValidatorManager
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
   * @inheritdoc IValidatorManager
   */
  function isBlockProducer(address _addr) public view override returns (bool) {
    return _validatorMap[_addr].hasFlag(EnumFlags.ValidatorFlag.BlockProducer);
  }

  /**
   * @inheritdoc IValidatorManager
   */
  function totalBlockProducers() external view returns (uint256 _total) {
    for (uint _i = 0; _i < validatorCount; _i++) {
      if (isBlockProducer(_validators[_i])) {
        _total++;
      }
    }
  }

  /**
   * @inheritdoc IValidatorManager
   */
  function getBridgeOperators() public view override returns (address[] memory _bridgeOperatorList) {
    _bridgeOperatorList = new address[](validatorCount);
    for (uint _i = 0; _i < _bridgeOperatorList.length; _i++) {
      _bridgeOperatorList[_i] = _candidateInfo[_validators[_i]].bridgeOperatorAddr;
    }
  }

  /**
   * @inheritdoc IValidatorManager
   */
  function isBridgeOperator(address _bridgeOperatorAddr) external view override returns (bool _result) {
    for (uint _i = 0; _i < validatorCount; _i++) {
      if (_candidateInfo[_validators[_i]].bridgeOperatorAddr == _bridgeOperatorAddr) {
        _result = true;
        break;
      }
    }
  }

  /**
   * @inheritdoc IValidatorManager
   */
  function maxValidatorNumber() external view override returns (uint256 _maximumValidatorNumber) {
    return _maxValidatorNumber;
  }

  /**
   * @inheritdoc IValidatorManager
   */
  function maxPrioritizedValidatorNumber() external view override returns (uint256 _maximumPrioritizedValidatorNumber) {
    return _maxPrioritizedValidatorNumber;
  }

  /**
   * Notice: A validator is always a bride operator
   *
   * @inheritdoc IValidatorManager
   */
  function totalBridgeOperators() public view returns (uint256) {
    return validatorCount;
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                               FUNCTIONS FOR ADMIN                                 //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc IValidatorManager
   */
  function setMaxValidatorNumber(uint256 _max) external override onlyAdmin {
    _setMaxValidatorNumber(_max);
  }

  /**
   * @inheritdoc IValidatorManager
   */
  function setMaxPrioritizedValidatorNumber(uint256 _number) external override onlyAdmin {
    _setMaxPrioritizedValidatorNumber(_number);
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                             OTHER HELPER FUNCTIONS                                //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev See {IValidatorManager-setMaxValidatorNumber}
   */
  function _setMaxValidatorNumber(uint256 _number) internal {
    _maxValidatorNumber = _number;
    emit MaxValidatorNumberUpdated(_number);
  }

  /**
   * @dev See {IValidatorManager-setMaxPrioritizedValidatorNumber}
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
