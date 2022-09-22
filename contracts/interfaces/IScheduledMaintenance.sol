// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IScheduledMaintenance {
  struct Schedule {
    uint256 startedAtBlock;
    uint256 endedAtBlock;
  }

  /// @dev Emitted when the maintenance is scheduled.
  event MaintenanceScheduled(address consensusAddr, Schedule);
  /// @dev Emitted when the maintenance config is updated.
  event MaintenanceConfigUpdated(
    uint256 minMaintenanceBlockPeriod,
    uint256 maxMaintenanceBlockPeriod,
    uint256 minOffset,
    uint256 maxSchedules
  );

  /**
   * @dev Returns whether the validator `_consensusAddr` is maintaining at the block number `_block`.
   */
  function maintaining(address _consensusAddr, uint256 _block) external view returns (bool);

  /**
   * @dev Returns the bool array indicating the validator is maintaining or not.
   */
  function bulkMaintaining(address[] calldata _addrList, uint256 _block) external view returns (bool[] memory);

  /**
   * @dev Returns whether the validator `_consensusAddr` has scheduled.
   */
  function scheduled(address _consensusAddr) external view returns (bool);

  /**
   * @dev Returns the detailed schedule of the validator `_consensusAddr`.
   */
  function getSchedule(address _consensusAddr) external view returns (Schedule memory);

  /**
   * @dev Returns the min block period for maintenance.
   */
  function minMaintenanceBlockPeriod() external view returns (uint256);

  /**
   * @dev Returns the max block period for maintenance.
   */
  function maxMaintenanceBlockPeriod() external view returns (uint256);

  /**
   * @dev Sets the min block period and max block period for maintenance.
   *
   * Requirements:
   * - The method caller is admin.
   * - The max period is larger than the min period.
   *
   * Emits the event `MaintenanceConfigUpdated`.
   *
   */
  function setMaintenanceConfig(
    uint256 _minMaintenanceBlockPeriod,
    uint256 _maxMaintenanceBlockPeriod,
    uint256 _minOffset,
    uint256 _maxSchedules
  ) external;

  /**
   * @dev Returns the min blocks from current block to the maintenance start block.
   */
  function minOffset() external view returns (uint256);

  /**
   * @dev Returns the max number of scheduled maintenances.
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
   * - The candidate `_consensusAddr` is the validator.
   * - The method caller is candidate admin of the candidate `_consensusAddr`.
   * - The candidate `_consensusAddr` has no schedule yet or the previous is done.
   * - The total number of schedules is not larger than `maxSchedules()`.
   * - The start block must be at least `minOffset()` blocks from the current block.
   * - The end block is larger than the start block.
   * - The scheduled block period is larger than the `minMaintenanceBlockPeriod()` and less than the `maxMaintenanceBlockPeriod()`.
   * - The start block is at the start of an epoch.
   * - The end block is at the end of an epoch.
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
