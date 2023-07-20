// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../../libraries/EnumFlags.sol";
import { HasTrustedOrgDeprecated } from "../../../utils/DeprecatedSlots.sol";
import "../../../extensions/collections/HasContracts.sol";
import "../../../interfaces/validator/info-fragments/IValidatorInfo.sol";
import "../../../interfaces/IProfile.sol";
import { TConsensus } from "../../../udvts/Types.sol";

abstract contract ValidatorInfoStorage is IValidatorInfo, HasContracts, HasTrustedOrgDeprecated {
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
   * @inheritdoc IValidatorInfo
   */
  function getValidators()
    public
    view
    override
    returns (
      address[] memory validatorList_,
      address[] memory bridgeOperators_,
      EnumFlags.ValidatorFlag[] memory flags_,
      address[] memory candidateIdList_
    )
  {
    validatorList_ = new address[](_validatorCount);
    bridgeOperators_ = new address[](_validatorCount);
    flags_ = new EnumFlags.ValidatorFlag[](_validatorCount);
    candidateIdList_ = new address[](_validatorCount);
    for (uint _i; _i < validatorList_.length; ) {
      address validatorId = _validatorIds[_i];
      validatorList_[_i] = validatorId;
      bridgeOperators_[_i] = _bridgeOperatorOfCandidateId(validatorId);
      flags_[_i] = _validatorMap[validatorId];
      candidateIdList_[_i] = validatorId;

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @inheritdoc IValidatorInfo
   */
  function isValidator(address consensusAddr) external view override returns (bool) {
    return !_validatorMap[consensusAddr].isNone();
  }

  /**
   * @inheritdoc IValidatorInfo
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
   * @inheritdoc IValidatorInfo
   */
  function isBlockProducer(TConsensus consensusAddr) public view override returns (bool) {
    return _isBlockProducerById(_convertC2P(consensusAddr));
  }

  function _isBlockProducerById(address id) internal view returns (bool) {
    return _validatorMap[id].hasFlag(EnumFlags.ValidatorFlag.BlockProducer);
  }

  /**
   * @inheritdoc IValidatorInfo
   */
  function totalBlockProducers() external view returns (uint256 total) {
    unchecked {
      for (uint _i; _i < _validatorCount; _i++) {
        if (_isBlockProducerById(_validatorIds[_i])) {
          total++;
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
    returns (address[] memory _bridgeOperatorList, address[] memory validatorList_)
  {
    uint256 _length = _validatorCount;
    _bridgeOperatorList = new address[](_length);
    validatorList_ = new address[](_length);
    uint256 _count = 0;
    unchecked {
      for (uint _i; _i < _length; ++_i) {
        if (_isOperatingBridgeById(_validatorIds[_i])) {
          address __validator = _validatorIds[_i];
          _bridgeOperatorList[_count] = _bridgeOperatorOfCandidateId(__validator);
          validatorList_[_count++] = __validator;
        }
      }
    }

    assembly {
      mstore(_bridgeOperatorList, _count)
      mstore(validatorList_, _count)
    }
  }

  /**
   * @inheritdoc IValidatorInfo
   */
  function getBridgeOperatorsOf(
    TConsensus[] memory consensusAddrs
  ) public view override returns (address[] memory bridgeOperatorList) {
    bridgeOperatorList = new address[](consensusAddrs.length);
    address[] memory validatorIds = _convertManyC2P(consensusAddrs);
    for (uint i; i < bridgeOperatorList.length; ) {
      bridgeOperatorList[i] = _bridgeOperatorOfCandidateId(validatorIds[i]);
      unchecked {
        ++i;
      }
    }
  }

  /**
   * @inheritdoc IValidatorInfo
   */
  function isBridgeOperator(address bridgeOperatorAddr) external view override returns (bool isOperator) {
    for (uint i; i < _validatorCount; ) {
      if (
        _bridgeOperatorOfCandidateId(_validatorIds[i]) == bridgeOperatorAddr && _isOperatingBridgeById(_validatorIds[i])
      ) {
        isOperator = true;
        break;
      }

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @inheritdoc IValidatorInfo
   */
  function isOperatingBridge(TConsensus consensus) external view override returns (bool) {
    return _isOperatingBridgeById(_convertC2P(consensus));
  }

  function _isOperatingBridgeById(address validatorId) internal view returns (bool) {
    return _validatorMap[validatorId].hasFlag(EnumFlags.ValidatorFlag.DeprecatedBridgeOperator);
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
      for (uint _i; _i < _validatorCount; _i++) {
        if (_isOperatingBridgeById(_validatorIds[_i])) {
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
  function _bridgeOperatorOfCandidateId(address _consensusAddr) internal view virtual returns (address);

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

  function _convertC2P(TConsensus consensusAddr) internal view virtual returns (address);

  function _convertManyC2P(TConsensus[] memory consensusAddrs) internal view virtual returns (address[] memory);
}
