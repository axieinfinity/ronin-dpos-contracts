// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBridgeManagerEvents {
  /**
   * @dev The structure representing information about a bridge operator.
   * @param addr The address of the bridge operator.
   * @param voteWeight The vote weight assigned to the bridge operator.
   */
  struct BridgeOperatorInfo {
    address addr;
    uint96 voteWeight;
  }

  /**
   * @dev Emitted when new bridge operators are added.
   * @param statuses The array of boolean values represents whether the corresponding bridge operator is added successfully.
   * @param voteWeights The array of vote weights assigned to the added bridge operators.
   * @param governors The array of addresses representing the governors associated with the added bridge operators.
   * @param bridgeOperators The array of addresses representing the added bridge operators.
   */
  event BridgeOperatorsAdded(bool[] statuses, uint96[] voteWeights, address[] governors, address[] bridgeOperators);

  /**
   * @dev Emitted when bridge operators are removed.
   * @param statuses The array of boolean values representing the statuses of the removed bridge operators.
   * @param bridgeOperators The array of addresses representing the removed bridge operators.
   */
  event BridgeOperatorsRemoved(bool[] statuses, address[] bridgeOperators);

  /**
   * @dev Emitted when a bridge operator is updated.
   * @param governor The address of the governor initiating the update.
   * @param fromBridgeOperator The address of the bridge operator being updated.
   * @param toBridgeOperator The updated address of the bridge operator.
   */
  event BridgeOperatorUpdated(
    address indexed governor,
    address indexed fromBridgeOperator,
    address indexed toBridgeOperator
  );
}
