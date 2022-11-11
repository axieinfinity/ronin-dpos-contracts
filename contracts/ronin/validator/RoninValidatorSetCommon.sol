// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../interfaces/validator/IRoninValidatorSetCommon.sol";
import "./CandidateManager.sol";

abstract contract RoninValidatorSetCommon is IRoninValidatorSetCommon, CandidateManager {
  /// @dev The last updated period
  uint256 internal _lastUpdatedPeriod;
  /// @dev The starting block of the last updated period
  uint256 internal _currentPeriodStartAtBlock;

  /// @dev Mapping from consensus address => period number => block producer has no pending reward
  mapping(address => mapping(uint256 => bool)) internal _miningRewardDeprecatedAtPeriod;
  /// @dev Mapping from consensus address => period number => whether the block producer get cut off reward, due to bailout
  mapping(address => mapping(uint256 => bool)) internal _miningRewardBailoutCutOffAtPeriod;
  /// @dev Mapping from consensus address => period number => block operator has no pending reward
  mapping(address => mapping(uint256 => bool)) internal _bridgeRewardDeprecatedAtPeriod;
  /// @dev Mapping from consensus address => the last block that the validator is jailed
  mapping(address => uint256) internal _jailedUntil;

  /// @dev Mapping from consensus address => pending reward from producing block
  mapping(address => uint256) internal _miningReward;
  /// @dev Mapping from consensus address => pending reward from delegating
  mapping(address => uint256) internal _delegatingReward;

  ///////////////////////////////////////////////////////////////////////////////////////
  //                             FUNCTIONS FOR NORMAL USER                             //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc ICandidateManager
   */
  function currentPeriod() public view virtual override(CandidateManager, ICandidateManager) returns (uint256) {
    return _lastUpdatedPeriod;
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function currentPeriodStartAtBlock() public view virtual override returns (uint256) {
    return _currentPeriodStartAtBlock;
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
}
