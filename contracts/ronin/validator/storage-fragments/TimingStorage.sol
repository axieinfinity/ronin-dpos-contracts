// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../../interfaces/validator/info-fragments/ITimingInfo.sol";

contract TimingStorage is ITimingInfo {
  /// @dev Length of period in seconds
  uint256 internal constant _periodLength = 1 days;

  /// @dev The number of blocks in a epoch
  uint256 internal _numberOfBlocksInEpoch;
  /// @dev The last updated block
  uint256 internal _lastUpdatedBlock;
  /// @dev The last updated period
  uint256 internal _lastUpdatedPeriod;
  /// @dev The starting block of the last updated period
  uint256 internal _currentPeriodStartAtBlock;

  /**
   * @inheritdoc ITimingInfo
   */
  function getLastUpdatedBlock() external view override returns (uint256) {
    return _lastUpdatedBlock;
  }

  /**
   * @inheritdoc ITimingInfo
   */
  function epochOf(uint256 _block) public view virtual override returns (uint256) {
    return _block / _numberOfBlocksInEpoch + 1;
  }

  /**
   * @inheritdoc ITimingInfo
   */
  function isPeriodEnding() external view override returns (bool) {
    return _isPeriodEnding(_computePeriod(block.timestamp));
  }

  /**
   * @inheritdoc ITimingInfo
   */
  function epochEndingAt(uint256 _block) public view virtual override returns (bool) {
    return _block % _numberOfBlocksInEpoch == _numberOfBlocksInEpoch - 1;
  }

  /**
   * @inheritdoc ITimingInfo
   */
  function currentPeriod() public view virtual override returns (uint256) {
    return _lastUpdatedPeriod;
  }

  /**
   * @inheritdoc ITimingInfo
   */
  function currentPeriodStartAtBlock() public view override returns (uint256) {
    return _currentPeriodStartAtBlock;
  }

  /**
   * @inheritdoc ITimingInfo
   */
  function numberOfBlocksInEpoch() public view virtual override returns (uint256 _numberOfBlocks) {
    return _numberOfBlocksInEpoch;
  }

  /**
   * @dev See `ITimingInfo-isPeriodEnding`
   */
  function _isPeriodEnding(uint256 _newPeriod) public view virtual returns (bool) {
    return _newPeriod > _lastUpdatedPeriod;
  }

  /**
   * @dev Returns the calculated period.
   */
  function _computePeriod(uint256 _timestamp) internal pure returns (uint256) {
    return _timestamp / _periodLength;
  }
}
