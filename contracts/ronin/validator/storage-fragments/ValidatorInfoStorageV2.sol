// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../../libraries/EnumFlags.sol";
import { HasTrustedOrgDeprecated } from "../../../utils/DeprecatedSlots.sol";
import "../../../extensions/collections/HasContracts.sol";
import "../../../interfaces/validator/info-fragments/IValidatorInfoV2.sol";
import "../../../interfaces/IProfile.sol";
import { TConsensus } from "../../../udvts/Types.sol";

abstract contract ValidatorInfoStorageV2 is IValidatorInfoV2, HasContracts, HasTrustedOrgDeprecated {
  using EnumFlags for EnumFlags.ValidatorFlag;

  /// @dev The maximum number of validator.
  uint256 internal _maxValidatorNumber;

  /// @dev The total of validators
  uint256 internal _validatorCount;
  /// @dev Mapping from validator index => validator id address
  mapping(uint256 => address) internal _validatorIds;
  /// @dev Mapping from validator id => flag indicating the validator ability: producing block, operating bridge
  mapping(address => EnumFlags.ValidatorFlag) internal _validatorMap;
  /// @dev The number of slot that is reserved for prioritized validators
  uint256 internal _maxPrioritizedValidatorNumber;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private ______gap;

  function validatorCount() external view returns (uint256) {
    return _validatorCount;
  }

  /**
   * @inheritdoc IValidatorInfoV2
   */
  function getValidators() public view override returns (address[] memory validatorList_) {
    validatorList_ = new address[](_validatorCount);
    address iValidator;
    for (uint i; i < validatorList_.length; ) {
      iValidator = _validatorIds[i];
      validatorList_[i] = iValidator;

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @inheritdoc IValidatorInfoV2
   */
  function getBlockProducers() public view override returns (address[] memory result) {
    result = new address[](_validatorCount);
    uint256 count = 0;
    for (uint i; i < result.length; ) {
      address validatorId = _validatorIds[i];
      if (_isBlockProducerById(validatorId)) {
        result[count++] = validatorId;
      }

      unchecked {
        ++i;
      }
    }

    assembly {
      mstore(result, count)
    }
  }

  /**
   * @inheritdoc IValidatorInfoV2
   */
  function isBlockProducer(TConsensus consensusAddr) public view override returns (bool) {
    return _isBlockProducerById(_convertC2P(consensusAddr));
  }

  function _isBlockProducerById(address id) internal view returns (bool) {
    return _validatorMap[id].hasFlag(EnumFlags.ValidatorFlag.BlockProducer);
  }

  /**
   * @inheritdoc IValidatorInfoV2
   */
  function totalBlockProducer() external view returns (uint256 total) {
    unchecked {
      for (uint i; i < _validatorCount; i++) {
        if (_isBlockProducerById(_validatorIds[i])) {
          total++;
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

  function _convertC2P(TConsensus consensusAddr) internal view virtual returns (address);

  function _convertManyC2P(TConsensus[] memory consensusAddrs) internal view virtual returns (address[] memory);
}
