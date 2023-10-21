// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title IBridgeManagerCallback
 * @dev Interface for the callback functions to be implemented by the Bridge Manager contract.
 */
interface IBridgeManagerCallback is IERC165 {
  /**
   * @dev Handles the event when bridge operators are added.
   * @param bridgeOperators The addresses of the bridge operators.
   * @param addeds The corresponding boolean values indicating whether the operators were added or not.
   * @return selector The selector of the function being called.
   */
  function onBridgeOperatorsAdded(
    address[] memory bridgeOperators,
    bool[] memory addeds
  ) external returns (bytes4 selector);

  /**
   * @dev Handles the event when bridge operators are removed.
   * @param bridgeOperators The addresses of the bridge operators.
   * @param removeds The corresponding boolean values indicating whether the operators were removed or not.
   * @return selector The selector of the function being called.
   */
  function onBridgeOperatorsRemoved(
    address[] memory bridgeOperators,
    bool[] memory removeds
  ) external returns (bytes4 selector);

  /**
   * @dev Handles the event when a bridge operator is updated.
   * @param currentBridgeOperator The address of the current bridge operator.
   * @param newbridgeOperator The new address of the bridge operator.
   * @return selector The selector of the function being called.
   */
  function onBridgeOperatorUpdated(
    address currentBridgeOperator,
    address newbridgeOperator
  ) external returns (bytes4 selector);
}
