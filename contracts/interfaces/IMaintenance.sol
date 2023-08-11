// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IMaintenance {
  /**
   * @dev Error thrown when attempting to schedule an already scheduled event.
   */
  error ErrAlreadyScheduled();

  /**
   * @dev Error thrown when referring to a non-existent schedule.
   */
  error ErrUnexistedSchedule();

  /**
   * @dev Error thrown when the end block of a schedule is out of range.
   */
  error ErrEndBlockOutOfRange();

  /**
   * @dev Error thrown when the start block of a schedule is out of range.
   */
  error ErrStartBlockOutOfRange();

  /**
   * @dev Error thrown when attempting to initiate maintenance while already in maintenance mode.
   */
  error ErrAlreadyOnMaintenance();

  /**
   * @dev Error thrown when attempting an action before the cooldown period has ended.
   */
  error ErrCooldownTimeNotYetEnded();

  /**
   * @dev Error thrown when the total number of schedules exceeds the limit.
   */
  error ErrTotalOfSchedulesExceeded();

  /**
   * @dev Error thrown when an invalid maintenance duration is specified.
   */
  error ErrInvalidMaintenanceDuration();

  /**
   * @dev Error thrown when an invalid maintenance duration configuration is provided.
   */
  error ErrInvalidMaintenanceDurationConfig();

  /**
   * @dev Error thrown when an invalid offset is specified to start the schedule configurations.
   */
  error ErrInvalidOffsetToStartScheduleConfigs();

  struct Schedule {
    uint256 from;
    uint256 to;
    uint256 lastUpdatedBlock;
    uint256 requestTimestamp;
  }

  /// @dev Emitted when a maintenance is scheduled.
  event MaintenanceScheduled(address indexed consensusAddr, Schedule);
  /// @dev Emitted when a schedule of maintenance is cancelled.
  event MaintenanceScheduleCancelled(address indexed consensusAddr);
  /// @dev Emitted when the maintenance config is updated.
  event MaintenanceConfigUpdated(
    uint256 minMaintenanceDurationInBlock,
    uint256 maxMaintenanceDurationInBlock,
    uint256 minOffsetToStartSchedule,
    uint256 maxOffsetToStartSchedule,
    uint256 maxSchedules,
    uint256 cooldownSecsToMaintain
  );

  /**
   * @dev Returns whether the validator `_consensusAddr` maintained at the block number `_block`.
   */
  function checkMaintained(address _consensusAddr, uint256 _block) external view returns (bool);

  /**
   * @dev Returns whether the validator `_consensusAddr` maintained in the inclusive range [`_fromBlock`, `_toBlock`] of blocks.
   */
  function checkMaintainedInBlockRange(
    address _consensusAddr,
    uint256 _fromBlock,
    uint256 _toBlock
  ) external view returns (bool);

  /**
   * @dev Returns the bool array indicating the validators maintained at block number `_block` or not.
   */
  function checkManyMaintained(address[] calldata _addrList, uint256 _block) external view returns (bool[] memory);

  /**
   * @dev Returns a bool array indicating the validators maintained in the inclusive range [`_fromBlock`, `_toBlock`] of blocks or not.
   */
  function checkManyMaintainedInBlockRange(
    address[] calldata _addrList,
    uint256 _fromBlock,
    uint256 _toBlock
  ) external view returns (bool[] memory);

  /**
   * @dev Returns whether the validator `_consensusAddr` has scheduled.
   */
  function checkScheduled(address _consensusAddr) external view returns (bool);

  /**
   * @dev Returns whether the validator `_consensusAddr`
   */
  function checkCooldownEnded(address _consensusAddr) external view returns (bool);

  /**
   * @dev Returns the detailed schedule of the validator `_consensusAddr`.
   */
  function getSchedule(address _consensusAddr) external view returns (Schedule memory);

  /**
   * @dev Returns the total of current schedules.
   */
  function totalSchedule() external view returns (uint256 _count);

  /**
   * @dev Sets the duration restriction, start time restriction, and max allowed for maintenance.
   *
   * Requirements:
   * - The method caller is admin.
   * - The max duration is larger than the min duration.
   * - The max offset is larger than the min offset.
   *
   * Emits the event `MaintenanceConfigUpdated`.
   *
   */
  function setMaintenanceConfig(
    uint256 _minMaintenanceDurationInBlock,
    uint256 _maxMaintenanceDurationInBlock,
    uint256 _minOffsetToStartSchedule,
    uint256 _maxOffsetToStartSchedule,
    uint256 _maxSchedules,
    uint256 _cooldownSecsToMaintain
  ) external;

  /**
   * @dev Returns the min duration for maintenance in block.
   */
  function minMaintenanceDurationInBlock() external view returns (uint256);

  /**
   * @dev Returns the max duration for maintenance in block.
   */
  function maxMaintenanceDurationInBlock() external view returns (uint256);

  /**
   * @dev The offset to the min block number that the schedule can start
   */
  function minOffsetToStartSchedule() external view returns (uint256);

  /**
   * @dev The offset to the max block number that the schedule can start
   */
  function maxOffsetToStartSchedule() external view returns (uint256);

  /**
   * @dev Returns the max number of scheduled maintenances.
   */
  function maxSchedule() external view returns (uint256);

  /**
   * @dev Schedules for maintenance from `_startedAtBlock` to `_startedAtBlock`.
   *
   * Requirements:
   * - The candidate `_consensusAddr` is the block producer.
   * - The method caller is candidate admin of the candidate `_consensusAddr`.
   * - The candidate `_consensusAddr` has no schedule yet or the previous is done.
   * - The total number of schedules is not larger than `maxSchedules()`.
   * - The start block must be at least `minOffsetToStartSchedule()` and at most `maxOffsetToStartSchedule()` blocks from the current block.
   * - The end block is larger than the start block.
   * - The scheduled duration is larger than the `minMaintenanceDurationInBlock()` and less than the `maxMaintenanceDurationInBlock()`.
   * - The start block is at the start of an epoch.
   * - The end block is at the end of an epoch.
   *
   * Emits the event `MaintenanceScheduled`.
   *
   */
  function schedule(address _consensusAddr, uint256 _startedAtBlock, uint256 _endedAtBlock) external;

  /**
   * @dev Cancel the schedule of maintenance for the `_consensusAddr`.
   *
   * Requirements:
   * - The candidate `_consensusAddr` is the block producer.
   * - The method caller is candidate admin of the candidate `_consensusAddr`.
   * - A schedule for the `_consensusAddr` must be existent and not executed yet.
   *
   * Emits the event `MaintenanceScheduleCancelled`.
   */
  function cancelSchedule(address _consensusAddr) external;
}
