// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../../interfaces/validator/managers/ISlashingInfoManager.sol";
import "./TimingManager.sol";

abstract contract SlashingInfoManager is ISlashingInfoManager, TimingManager {
  /// @dev Mapping from consensus address => period number => block producer has no pending reward
  mapping(address => mapping(uint256 => bool)) internal _miningRewardDeprecatedAtPeriod;
  /// @dev Mapping from consensus address => period number => whether the block producer get cut off reward, due to bailout
  mapping(address => mapping(uint256 => bool)) internal _miningRewardBailoutCutOffAtPeriod;
  /// @dev Mapping from consensus address => period number => block operator has no pending reward
  mapping(address => mapping(uint256 => bool)) internal _bridgeRewardDeprecatedAtPeriod;
  /// @dev Mapping from consensus address => the last block that the validator is jailed
  mapping(address => uint256) internal _jailedUntil;

  /**
   * @inheritdoc ISlashingInfoManager
   */
  function jailed(address _addr) external view override returns (bool) {
    return jailedAtBlock(_addr, block.number);
  }

  /**
   * @inheritdoc ISlashingInfoManager
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
   * @inheritdoc ISlashingInfoManager
   */
  function jailedAtBlock(address _addr, uint256 _blockNum) public view override returns (bool) {
    return _jailedAtBlock(_addr, _blockNum);
  }

  /**
   * @inheritdoc ISlashingInfoManager
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
    uint256 _jailedBlock = _jailedUntil[_addr];
    if (_jailedBlock < _blockNum) {
      return (false, 0, 0);
    }

    isJailed_ = true;
    blockLeft_ = _jailedBlock - _blockNum + 1;
    epochLeft_ = epochOf(_jailedBlock) - epochOf(_blockNum) + 1;
  }

  /**
   * @inheritdoc ISlashingInfoManager
   */
  function bulkJailed(address[] calldata _addrList) external view override returns (bool[] memory _result) {
    _result = new bool[](_addrList.length);
    for (uint256 _i; _i < _addrList.length; _i++) {
      _result[_i] = _jailed(_addrList[_i]);
    }
  }

  /**
   * @inheritdoc ISlashingInfoManager
   */
  function miningRewardDeprecated(address[] calldata _blockProducers)
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
   * @inheritdoc ISlashingInfoManager
   */
  function miningRewardDeprecatedAtPeriod(address[] calldata _blockProducers, uint256 _period)
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
  //                             OTHER HELPER FUNCTIONS                                //
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
}
