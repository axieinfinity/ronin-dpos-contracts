// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { TConsensus } from "../udvts/Types.sol";

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
  event MaintenanceScheduled(address indexed cid, Schedule);
  /// @dev Emitted when a schedule of maintenance is cancelled.
  event MaintenanceScheduleCancelled(address indexed cid);
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
   * @dev Returns whether the validator `consensusAddr` maintained at the block number `_block`.
   */
  function checkMaintained(TConsensus consensusAddr, uint256 _block) external view returns (bool);

  /**
   * @dev Returns whether the validator whose id `validatorId` maintained at the block number `_block`.
   */
  function checkMaintainedById(address validatorId, uint256 _block) external view returns (bool);

  /**
   * @dev Returns whether the validator `consensusAddr` maintained in the inclusive range [`_fromBlock`, `_toBlock`] of blocks.
   */
  function checkMaintainedInBlockRange(
    TConsensus consensusAddr,
    uint256 _fromBlock,
    uint256 _toBlock
  ) external view returns (bool);

  /**
   * @dev Returns the bool array indicating the validators maintained at block number `k` or not.
   */
  function checkManyMaintained(
    TConsensus[] calldata consensusAddrList,
    uint256 atBlock
  ) external view returns (bool[] memory);

  function checkManyMaintainedById(
    address[] calldata candidateIdList,
    uint256 atBlock
  ) external view returns (bool[] memory);

  /**
   * @dev Returns a bool array indicating the validators maintained in the inclusive range [`_fromBlock`, `_toBlock`] of blocks or not.
   */
  function checkManyMaintainedInBlockRange(
    TConsensus[] calldata _consensusAddrList,
    uint256 _fromBlock,
    uint256 _toBlock
  ) external view returns (bool[] memory);

  function checkManyMaintainedInBlockRangeById(
    address[] calldata idList,
    uint256 fromBlock,
    uint256 toBlock
  ) external view returns (bool[] memory);

  /**
   * @dev Returns whether the validator `consensusAddr` has finished cooldown.
   */
  function checkCooldownEnded(TConsensus consensusAddr) external view returns (bool);

  /**
   * @dev Returns whether the validator `consensusAddr` has schedule.
   */
  function checkScheduled(TConsensus consensusAddr) external view returns (bool);

  /**
   * @dev Returns the detailed schedule of the validator `consensusAddr`.
   */
  function getSchedule(TConsensus consensusAddr) external view returns (Schedule memory);

  /**
   * @dev Returns the total of current schedules.
   */
  function totalSchedule() external view returns (uint256 count);

  /**
   * @dev Returns the cooldown to maintain in seconds.
   */
  function cooldownSecsToMaintain() external view returns (uint256);

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
    uint256 minMaintenanceDurationInBlock_,
    uint256 maxMaintenanceDurationInBlock_,
    uint256 minOffsetToStartSchedule_,
    uint256 maxOffsetToStartSchedule_,
    uint256 maxSchedules_,
    uint256 cooldownSecsToMaintain_
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
   * @dev Schedules for maintenance from `startedAtBlock` to `endedAtBlock`.
   *
   * Requirements:
   * - The candidate `consensusAddr` is the block producer.
   * - The method caller is candidate admin of the candidate `consensusAddr`.
   * - The candidate `consensusAddr` has no schedule yet or the previous is done.
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
  function schedule(TConsensus consensusAddr, uint256 startedAtBlock, uint256 endedAtBlock) external;

  /**
   * @dev Cancel the schedule of maintenance for the `consensusAddr`.
   *
   * Requirements:
   * - The candidate `consensusAddr` is the block producer.
   * - The method caller is candidate admin of the candidate `consensusAddr`.
   * - A schedule for the `consensusAddr` must be existent and not executed yet.
   *
   * Emits the event `MaintenanceScheduleCancelled`.
   */
  function cancelSchedule(TConsensus consensusAddr) external;
}
