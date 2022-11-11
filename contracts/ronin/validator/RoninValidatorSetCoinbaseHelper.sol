// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../interfaces/validator/IRoninValidatorSetCoinbaseHelper.sol";
import "../../libraries/EnumFlags.sol";
import "./BaseRoninValidatorSet.sol";
import "./RoninValidatorSetCommon.sol";

abstract contract RoninValidatorSetCoinbaseHelper is
  IRoninValidatorSetCoinbaseHelper,
  BaseRoninValidatorSet,
  RoninValidatorSetCommon
{
  using EnumFlags for EnumFlags.ValidatorFlag;

  /// @dev The last updated block
  uint256 internal _lastUpdatedBlock;

  /// @dev The total of validators
  uint256 public validatorCount;
  /// @dev Mapping from validator index => validator address
  mapping(uint256 => address) internal _validators;
  /// @dev Mapping from address => flag indicating the validator ability: producing block, operating bridge
  mapping(address => EnumFlags.ValidatorFlag) internal _validatorMap;

  /// @dev The total reward for bridge operators
  uint256 internal _totalBridgeReward;
  /// @dev Mapping from consensus address => pending reward for being bridge operator
  mapping(address => uint256) internal _bridgeOperatingReward;

  modifier onlyCoinbase() {
    require(msg.sender == block.coinbase, "RoninValidatorSet: method caller must be coinbase");
    _;
  }

  modifier whenEpochEnding() {
    require(epochEndingAt(block.number), "RoninValidatorSet: only allowed at the end of epoch");
    _;
  }

  modifier oncePerEpoch() {
    require(
      epochOf(_lastUpdatedBlock) < epochOf(block.number),
      "RoninValidatorSet: query for already wrapped up epoch"
    );
    _lastUpdatedBlock = block.number;
    _;
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                           FUNCTIONS FOR EPOCH CONTROL                             //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc IRoninValidatorSetCoinbaseHelper
   */
  function getLastUpdatedBlock() external view override returns (uint256) {
    return _lastUpdatedBlock;
  }

  /**
   * @inheritdoc IRoninValidatorSetCoinbaseHelper
   */
  function epochOf(uint256 _block) public view virtual override returns (uint256) {
    return _block == 0 ? 0 : _block / _numberOfBlocksInEpoch + 1;
  }

  /**
   * @inheritdoc IRoninValidatorSetCoinbaseHelper
   */
  function epochEndingAt(uint256 _block) public view virtual returns (bool) {
    return _block % _numberOfBlocksInEpoch == _numberOfBlocksInEpoch - 1;
  }

  /**
   * @inheritdoc IRoninValidatorSetCoinbaseHelper
   */
  function isPeriodEnding() external view virtual returns (bool) {
    return _isPeriodEnding(_computePeriod(block.timestamp));
  }

  /**
   * @dev Helper for {IRoninValidatorSetCoinbaseHelper-isPeriodEnding}
   */
  function _isPeriodEnding(uint256 _newPeriod) public view virtual returns (bool) {
    return _newPeriod > _lastUpdatedPeriod;
  }

  /**
   * @dev Returns the calculated period.
   */
  function _computePeriod(uint256 _timestamp) internal pure returns (uint256) {
    return _timestamp / 1 days;
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                        QUERY FUNCTIONS ABOUT VALIDATORS                           //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc IRoninValidatorSetCoinbaseHelper
   */
  function getValidators() public view override returns (address[] memory _validatorList) {
    _validatorList = new address[](validatorCount);
    for (uint _i = 0; _i < _validatorList.length; _i++) {
      _validatorList[_i] = _validators[_i];
    }
  }

  /**
   * @inheritdoc IRoninValidatorSetCoinbaseHelper
   */
  function isValidator(address _addr) public view override returns (bool) {
    return !_validatorMap[_addr].isNone();
  }

  /**
   * @inheritdoc IRoninValidatorSetCoinbaseHelper
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
   * @inheritdoc IRoninValidatorSetCoinbaseHelper
   */
  function isBlockProducer(address _addr) public view override returns (bool) {
    return _validatorMap[_addr].hasFlag(EnumFlags.ValidatorFlag.BlockProducer);
  }

  /**
   * @inheritdoc IRoninValidatorSetCoinbaseHelper
   */
  function totalBlockProducers() external view returns (uint256 _total) {
    for (uint _i = 0; _i < validatorCount; _i++) {
      if (isBlockProducer(_validators[_i])) {
        _total++;
      }
    }
  }

  /**
   * @inheritdoc IRoninValidatorSetCoinbaseHelper
   */
  function getBridgeOperators() public view override returns (address[] memory _bridgeOperatorList) {
    _bridgeOperatorList = new address[](validatorCount);
    for (uint _i = 0; _i < _bridgeOperatorList.length; _i++) {
      _bridgeOperatorList[_i] = _candidateInfo[_validators[_i]].bridgeOperatorAddr;
    }
  }

  /**
   * @inheritdoc IRoninValidatorSetCoinbaseHelper
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
   * Notice: A validator is always a bride operator
   *
   * @inheritdoc IRoninValidatorSetCoinbaseHelper
   */
  function totalBridgeOperators() public view returns (uint256) {
    return validatorCount;
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                QUERY FUNCTION ABOUT JAILING AND DEPRECATED REWARDS                //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc IRoninValidatorSetCoinbaseHelper
   */
  function jailed(address _addr) external view override returns (bool) {
    return jailedAtBlock(_addr, block.number);
  }

  /**
   * @inheritdoc IRoninValidatorSetCoinbaseHelper
   */
  function jailedTimeLeft(address _addr)
    external
    view
    override
    returns (
      bool isJailed_,
      uint256 blockLeft_,
      uint256 epochLeft_
    )
  {
    return jailedTimeLeftAtBlock(_addr, block.number);
  }

  /**
   * @inheritdoc IRoninValidatorSetCoinbaseHelper
   */
  function jailedAtBlock(address _addr, uint256 _blockNum) public view override returns (bool) {
    return _jailedAtBlock(_addr, _blockNum);
  }

  /**
   * @inheritdoc IRoninValidatorSetCoinbaseHelper
   */
  function jailedTimeLeftAtBlock(address _addr, uint256 _blockNum)
    public
    view
    override
    returns (
      bool isJailed_,
      uint256 blockLeft_,
      uint256 epochLeft_
    )
  {
    uint256 __jailedUntil = _jailedUntil[_addr];
    if (__jailedUntil < _blockNum) {
      return (false, 0, 0);
    }

    isJailed_ = true;
    blockLeft_ = __jailedUntil - _blockNum + 1;
    epochLeft_ = epochOf(__jailedUntil) - epochOf(_blockNum) + 1;
  }

  /**
   * @inheritdoc IRoninValidatorSetCoinbaseHelper
   */
  function bulkJailed(address[] memory _addrList) external view override returns (bool[] memory _result) {
    _result = new bool[](_addrList.length);
    for (uint256 _i; _i < _addrList.length; _i++) {
      _result[_i] = _jailed(_addrList[_i]);
    }
  }

  /**
   * @inheritdoc IRoninValidatorSetCoinbaseHelper
   */
  function miningRewardDeprecated(address[] memory _blockProducers)
    external
    view
    override
    returns (bool[] memory _result)
  {
    _result = new bool[](_blockProducers.length);
    uint256 _period = currentPeriod();
    for (uint256 _i; _i < _blockProducers.length; _i++) {
      _result[_i] = _miningRewardDeprecated(_blockProducers[_i], _period);
    }
  }

  /**
   * @inheritdoc IRoninValidatorSetCoinbaseHelper
   */
  function miningRewardDeprecatedAtPeriod(address[] memory _blockProducers, uint256 _period)
    external
    view
    override
    returns (bool[] memory _result)
  {
    _result = new bool[](_blockProducers.length);
    for (uint256 _i; _i < _blockProducers.length; _i++) {
      _result[_i] = _miningRewardDeprecated(_blockProducers[_i], _period);
    }
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                         HELPER FUNCTIONS FOR JAILING INFO                         //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Returns whether the reward of the validator is put in jail (cannot join the set of validators) during the current period.
   */
  function _jailed(address _validatorAddr) internal view returns (bool) {
    return _jailedAtBlock(_validatorAddr, block.number);
  }

  /**
   * @dev Returns whether the reward of the validator is put in jail (cannot join the set of validators) at a specific block.
   */
  function _jailedAtBlock(address _validatorAddr, uint256 _blockNum) internal view returns (bool) {
    return _blockNum <= _jailedUntil[_validatorAddr];
  }

  /**
   * @dev Returns whether the block producer has no pending reward in that period.
   */
  function _miningRewardDeprecated(address _validatorAddr, uint256 _period) internal view returns (bool) {
    return _miningRewardDeprecatedAtPeriod[_validatorAddr][_period];
  }

  /**
   * @dev Returns whether the bridge operator has no pending reward in the period.
   */
  function _bridgeRewardDeprecated(address _validatorAddr, uint256 _period) internal view returns (bool) {
    return _bridgeRewardDeprecatedAtPeriod[_validatorAddr][_period];
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                               OVERRIDDEN FUNCTIONS                                //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc ICandidateManager
   */
  function currentPeriod() public view virtual override(CandidateManager, RoninValidatorSetCommon) returns (uint256) {
    return RoninValidatorSetCommon.currentPeriod();
  }
}
