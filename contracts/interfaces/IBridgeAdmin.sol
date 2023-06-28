// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IBridgeAdmin
 * @dev The interface for managing bridge operators.
 */
interface IBridgeAdmin {
  /**
   * @dev Enum representing the actions that can be performed on bridge operators.
   * - Add: Add a bridge operator.
   * - Update: Update a bridge operator.
   * - Remove: Remove a bridge operator.
   */
  enum BridgeAction {
    Add,
    Update,
    Remove
  }

  struct BridgeOperator {
    address addr;
  }

  /**
   * @dev Emitted when a bridge operator is modified.
   * @param operator The address of the bridge operator being modified.
   * @param action The action performed on the bridge operator.
   */
  event OperatorSetModified(address indexed operator, BridgeAction indexed action);

  /**
   * @dev Returns the total number of bridge operators.
   * @return The total number of bridge operators.
   */
  function totalBridgeOperators() external view returns (uint256);

  /**
   * @dev Checks if the given address is a bridge operator.
   * @param addr The address to check.
   * @return A boolean indicating whether the address is a bridge operator.
   */
  function isBridgeOperator(address addr) external view returns (bool);

  /**
   * @dev Returns an array of all bridge operators.
   * @return An array containing the addresses of all bridge operators.
   */
  function getBridgeOperators() external view returns (address[] memory);

  /**
   * @dev Adds multiple bridge operators.
   * @param authAccounts An array of addresses of hot/cold wallets for bridge operator to update their node address.
   * @param bridgeOperators An array of addresses representing the bridge operators to add.
   * @return addeds An array of booleans indicating whether each bridge operator was added successfully.
   */
  function addBridgeOperators(
    address[] calldata authAccounts,
    address[] calldata bridgeOperators
  ) external returns (bool[] memory addeds);

  /**
   * @dev Removes multiple bridge operators.
   * @param bridgeOperators An array of addresses representing the bridge operators to remove.
   * @return removeds An array of booleans indicating whether each bridge operator was removed successfully.
   */
  function removeBridgeOperators(address[] calldata bridgeOperators) external returns (bool[] memory removeds);

  /**
   * @dev Updates a bridge operator.
   * @param bridgeOperator The address of the bridge operator to update.
   * @return updated A boolean indicating whether the bridge operator was updated successfully.
   */
  function updateBridgeOperator(address bridgeOperator) external returns (bool updated);
}
