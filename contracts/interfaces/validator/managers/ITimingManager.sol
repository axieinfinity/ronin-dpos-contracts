// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ITimingManager {
  /**
   * @dev Returns the block that validator set was updated.
   */
  function getLastUpdatedBlock() external view returns (uint256);

  /**
   * @dev Returns the number of blocks in a epoch.
   */
  function numberOfBlocksInEpoch() external view returns (uint256 _numberOfBlocks);

  /**
   * @dev Returns the epoch index from the block number.
   */
  function epochOf(uint256 _block) external view returns (uint256);

  /**
   * @dev Returns whether the epoch ending is at the block number `_block`.
   */
  function epochEndingAt(uint256 _block) external view returns (bool);

  /**
   * @dev Returns whether the period ending at the current block number.
   */
  function isPeriodEnding() external view returns (bool);

  /**
   * @dev Returns the period index from the current block.
   */
  function currentPeriod() external view returns (uint256);

  /**
   * @dev Returns the block number that the current period starts at.
   */
  function currentPeriodStartAtBlock() external view returns (uint256);
}
