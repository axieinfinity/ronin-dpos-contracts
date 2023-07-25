// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBridgeSlashEvents {
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
    uint128 slashUntilPeriod;
    uint128 newlyAddedAtPeriod;
  }

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
}
