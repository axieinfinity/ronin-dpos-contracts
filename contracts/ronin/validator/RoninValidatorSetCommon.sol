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
  //                               OVERRIDDEN FUNCTIONS                                //
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
}
