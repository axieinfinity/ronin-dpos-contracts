// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IBridgeSlashEvents } from "./events/IBridgeSlashEvents.sol";

/**
 * @title IBridgeSlash
 * @dev Interface for the BridgeSlash contract to manage slashing functionality for bridge operators.
 */
interface IBridgeSlash is IBridgeSlashEvents {
  /**
   * @dev Slashes the unavailability of bridge operators during a specific period.
   * @param period The period to slash the bridge operators for.
   */
  function execSlashBridgeOperators(
    address[] calldata operators,
    uint256[] calldata ballots,
    uint256 totalBallot,
    uint256 totalVote,
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
   * @param totalVote The total vote count for the period.
   * @return tier The slash tier.
   */
  function getSlashTier(uint256 ballot, uint256 totalVote) external pure returns (Tier tier);

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

  /**
   * @dev External function to retrieve the value of the minimum vote threshold to execute slashing rule.
   * @return minimumVoteThreshold The minimum vote threshold value.
   */
  function MINIMUM_VOTE_THRESHOLD() external view returns (uint256);
}
