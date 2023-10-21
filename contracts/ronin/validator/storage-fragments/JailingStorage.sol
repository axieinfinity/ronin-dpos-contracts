// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../../interfaces/validator/info-fragments/IJailingInfo.sol";
import "./TimingStorage.sol";

abstract contract JailingStorage is IJailingInfo {
  /// @dev Mapping from consensus address => period number => block producer has no pending reward.
  mapping(address => mapping(uint256 => bool)) internal _miningRewardDeprecatedAtPeriod;
  /// @dev Mapping from consensus address => period number => whether the block producer get cut off reward, due to bailout.
  mapping(address => mapping(uint256 => bool)) internal _miningRewardBailoutCutOffAtPeriod;
  /// @dev Mapping from consensus address => period number => block operator has no pending reward.
  mapping(address => mapping(uint256 => bool)) internal ______deprecatedBridgeRewardDeprecatedAtPeriod;

  /// @dev Mapping from consensus address => the last block that the block producer is jailed.
  mapping(address => uint256) internal _blockProducerJailedBlock;
  /// @dev Mapping from consensus address => the last timestamp that the bridge operator is jailed.
  mapping(address => uint256) internal _emergencyExitJailedTimestamp;
  /// @dev Mapping from consensus address => the last block that the block producer cannot bailout.
  mapping(address => uint256) internal _cannotBailoutUntilBlock;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[48] private ______gap;

  /**
   * @inheritdoc IJailingInfo
   */
  function checkJailed(address _addr) external view override returns (bool) {
    return checkJailedAtBlock(_addr, block.number);
  }

  /**
   * @inheritdoc IJailingInfo
   */
  function getJailedTimeLeft(
    address _addr
  ) external view override returns (bool isJailed_, uint256 blockLeft_, uint256 epochLeft_) {
    return getJailedTimeLeftAtBlock(_addr, block.number);
  }

  /**
   * @inheritdoc IJailingInfo
   */
  function checkJailedAtBlock(address _addr, uint256 _blockNum) public view override returns (bool) {
    return _jailedAtBlock(_addr, _blockNum);
  }

  /**
   * @inheritdoc IJailingInfo
   */
  function getJailedTimeLeftAtBlock(
    address _addr,
    uint256 _blockNum
  ) public view override returns (bool isJailed_, uint256 blockLeft_, uint256 epochLeft_) {
    uint256 _jailedBlock = _blockProducerJailedBlock[_addr];
    if (_jailedBlock < _blockNum) {
      return (false, 0, 0);
    }

    isJailed_ = true;
    blockLeft_ = _jailedBlock - _blockNum + 1;
    epochLeft_ = epochOf(_jailedBlock) - epochOf(_blockNum) + 1;
  }

  /**
   * @inheritdoc IJailingInfo
   */
  function checkManyJailed(address[] calldata _addrList) external view override returns (bool[] memory _result) {
    _result = new bool[](_addrList.length);
    for (uint256 _i; _i < _addrList.length; ) {
      _result[_i] = _jailed(_addrList[_i]);

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @inheritdoc IJailingInfo
   */
  function checkMiningRewardDeprecated(address _blockProducer) external view override returns (bool _result) {
    uint256 _period = currentPeriod();
    return _miningRewardDeprecated(_blockProducer, _period);
  }

  /**
   * @inheritdoc IJailingInfo
   */
  function checkMiningRewardDeprecatedAtPeriod(
    address _blockProducer,
    uint256 _period
  ) external view override returns (bool _result) {
    return _miningRewardDeprecated(_blockProducer, _period);
  }

  /**
   * @dev See `ITimingInfo-epochOf`
   */
  function epochOf(uint256 _block) public view virtual returns (uint256);

  /**
   * @dev See `ITimingInfo-currentPeriod`
   */
  function currentPeriod() public view virtual returns (uint256);

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
    return _blockNum <= _blockProducerJailedBlock[_validatorAddr];
  }

  /**
   * @dev Returns whether the block producer has no pending reward in that period.
   */
  function _miningRewardDeprecated(address _validatorAddr, uint256 _period) internal view returns (bool) {
    return _miningRewardDeprecatedAtPeriod[_validatorAddr][_period];
  }
}
