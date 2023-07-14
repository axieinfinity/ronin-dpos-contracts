// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IBridgeSlash
 * @dev Interface for the BridgeSlash contract to manage slashing functionality for bridge operators.
 */
interface IBridgeSlash {
  /**
   * @dev Enumeration representing the slashing tiers for bridge operators.
   */
  enum Tier {
    Tier0,
    Tier1,
    Tier2
  }

  /**
   * @dev Struct representing the status of a bridge operator.
   */
  struct BridgeSlashInfo {
    uint64 slashUntilPeriod;
    uint192 newlyAddedAtPeriod;
  }

  /**
   * @dev Emitted when new bridge operators are added.
   * @param period The period in which the bridge operators are added.
   * @param bridgeOperators The array of addresses representing the newly added bridge operators.
   */
  event NewBridgeOperatorsAdded(uint256 indexed period, address[] bridgeOperators);

  /**
   * @dev Event emitted when a bridge operator is slashed.
   * @param tier The slash tier of the operator.
   * @param bridgeOperator The address of the slashed bridge operator.
   * @param period The period in which the operator is slashed.
   * @param slashUntilPeriod The period until which the operator is penalized.
   */
  event Slashed(Tier indexed tier, address indexed bridgeOperator, uint256 indexed period, uint256 slashUntilPeriod);

  /**
   * @dev Emitted when a removal request is made for a bridge operator.
   * @param period The period for which the removal request is made.
   * @param bridgeOperator The address of the bridge operator being requested for removal.
   */
  event RemovalRequested(uint256 indexed period, address indexed bridgeOperator);

  /**
   * @dev Slashes the unavailability of bridge operators during a specific period.
   * @param period The period to slash the bridge operators for.
   */
  function execSlashBridgeOperators(
    address[] calldata operators,
    uint256[] calldata ballots,
    uint256 totalBallotsForPeriod,
    uint256 period
  ) external;

  /**
   * @dev Returns the penalize durations for the specified bridge operators.
   * @param bridgeOperators The addresses of the bridge operators.
   * @return untilPeriods The penalized periods for the bridge operators.
   */
  function getSlashUntilPeriodOf(address[] calldata bridgeOperators) external returns (uint256[] memory untilPeriods);

  /**
   * @dev Retrieves the added periods of the specified bridge operators.
   * @param bridgeOperators An array of bridge operator addresses.
   * @return addedPeriods An array of uint256 values representing the added periods for each bridge operator.
   */
  function getAddedPeriodOf(address[] calldata bridgeOperators) external view returns (uint256[] memory addedPeriods);

  /**
   * @dev Gets the slash tier based on the given ballot and total ballots.
   * @param ballot The ballot count for a bridge operator.
   * @param totalBallots The total ballot count for the period.
   * @return tier The slash tier.
   */
  function getSlashTier(uint256 ballot, uint256 totalBallots) external pure returns (Tier tier);

  /**
   * @dev Retrieve the penalty durations for different slash tiers.
   * @return penaltyDurations The array of penalty durations for each slash tier.
   */
  function getPenaltyDurations() external pure returns (uint256[] memory penaltyDurations);

  /**
   * @dev Returns the penalty duration for Tier 1 slashing.
   * @return The duration in period number for Tier 1 slashing.
   */
  function TIER_1_PENALTY_DURATION() external view returns (uint256);

  /**
   * @dev Returns the penalty duration for Tier 2 slashing.
   * @return The duration in period number for Tier 2 slashing.
   */
  function TIER_2_PENALTY_DURATION() external view returns (uint256);

  /**
   * @dev Returns the threshold duration for removing bridge operators.
   * @return The duration in period number that exceeds which a bridge operator will be removed.
   */
  function REMOVE_DURATION_THRESHOLD() external view returns (uint256);
}
