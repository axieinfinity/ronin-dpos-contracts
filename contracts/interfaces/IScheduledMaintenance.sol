// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IScheduledMaintenance {
  struct Schedule {
    uint256 startedAtBlock;
    uint256 endedAtBlock;
  }

  /// @dev Emitted when the maintenance is scheduled.
  event MaintenanceScheduled(address consensusAddr, Schedule);

  /**
   * @dev Returns whether the validator `_consensusAddr` is maintained at the current block.
   */
  function maintained(address _consensusAddr) external view returns (bool);

  /**
   * @dev Returns whether the validator `_consensusAddr` has scheduled.
   */
  function scheduled(address _consensusAddr) external view returns (bool);

  /**
   * @dev Returns the detailed schedule of the validator `_consensusAddr`.
   */
  function getSchedule(address _consensusAddr) external view returns (Schedule memory);

  /**
   * @dev Returns the minimum block size to maintenance.
   */
  function minMaintenanceBlockSize() external view returns (uint256);

  /**
   * @dev Returns the maximum block size to maintenance.
   */
  function maxMaintenanceBlockSize() external view returns (uint256);

  /**
   * @dev Returns the minimum blocks from the current block to the start block.
   */
  function minOffset() external view returns (uint256);

  /**
   * @dev Returns the maximum number of scheduled maintenances.
   */
  function maxSchedules() external view returns (uint256);

  /**
   * @dev Returns the total of current schedules.
   */
  function totalSchedules() external view returns (uint256 _count);

  /**
   * @dev Schedules for maintenance from `_startedAtBlock` to `_startedAtBlock`.
   *
   * Requirements:
   * - The method caller is candidate owner of the candidate `_consensusAddr`.
   * - The candidate `_consensusAddr` is the validator.
   * - The candidate `_consensusAddr` has no schedule yet.
   * - The total number of current scheduled maintenances is not larger than `maxSchedules()`.
   * - The end block is larger than the start block.
   * - The scheduled block size is larger than the `minMaintenanceBlockSize()`.
   * - The start block must be at least `minOffset()` blocks from the current block.
   *
   * Emits the event `MaintenanceScheduled`.
   *
   */
  function schedule(
    address _consensusAddr,
    uint256 _startedAtBlock,
    uint256 _endedAtBlock
  ) external;
}
