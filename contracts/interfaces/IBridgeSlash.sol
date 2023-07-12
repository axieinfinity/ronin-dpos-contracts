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
    uint64 penalizedDuration;
    uint192 newlyAddedAtPeriod;
  }

  /**
   * @dev Event emitted when a bridge operator is slashed.
   * @param tier The slash tier of the operator.
   * @param bridgeOperator The address of the slashed bridge operator.
   * @param period The period in which the operator is slashed.
   * @param until The timestamp until which the operator is penalized.
   */
  event Slashed(Tier indexed tier, address indexed bridgeOperator, uint256 indexed period, uint256 until);

  /**
   * @dev Slashes the unavailability of bridge operators during a specific period.
   * @param period The period to slash the bridge operators for.
   */
  function slashUnavailability(uint256 period) external;

  function TIER_1_PENALIZE_DURATION() external view returns (uint256);

  function TIER_2_PENALIZE_DURATION() external view returns (uint256);

  function REMOVE_DURATION_THRESHOLD() external view returns (uint256);

  /**
   * @dev Returns the penalize durations for the specified bridge operators.
   * @param bridgeOperators The addresses of the bridge operators.
   * @return durations The penalized durations for the bridge operators.
   */
  function penalizeDurationOf(address[] calldata bridgeOperators) external returns (uint256[] memory durations);
}
