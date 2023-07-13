// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IBridgeSlash } from "@ronin/contracts/interfaces/bridge/IBridgeSlash.sol";

interface IBridgeSlashEventsTest {
  /**
   * @dev Event emitted when a bridge operator is slashed.
   * @param tier The slash tier of the operator.
   * @param bridgeOperator The address of the slashed bridge operator.
   * @param period The period in which the operator is slashed.
   * @param until The timestamp until which the operator is penalized.
   */
  event Slashed(IBridgeSlash.Tier indexed tier, address indexed bridgeOperator, uint256 indexed period, uint256 until);
}
