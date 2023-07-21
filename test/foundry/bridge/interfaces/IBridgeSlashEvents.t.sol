// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IBridgeSlash } from "@ronin/contracts/interfaces/bridge/IBridgeSlash.sol";

interface IBridgeSlashEventsTest {
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
   * @param until The timestamp until which the operator is penalized.
   */
  event Slashed(IBridgeSlash.Tier indexed tier, address indexed bridgeOperator, uint256 indexed period, uint256 until);

  /**
   * @dev Emitted when a removal request is made for a bridge operator.
   * @param period The period for which the removal request is made.
   * @param bridgeOperator The address of the bridge operator being requested for removal.
   */
  event RemovalRequested(uint256 indexed period, address indexed bridgeOperator);
}
