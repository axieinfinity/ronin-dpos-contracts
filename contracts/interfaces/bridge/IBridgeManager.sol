// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IBridgeManager
 * @dev The interface for managing bridge operators.
 */
interface IBridgeManager {
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
  event BridgeOperatorsAdded(bool[] statuses, uint256[] voteWeights, address[] governors, address[] bridgeOperators);

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

  /**
   * @dev The domain separator used for computing hash digests in the contract.
   */
  function DOMAIN_SEPARATOR() external view returns (bytes32);

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

  function getFullBridgeOperatorInfos()
    external
    view
    returns (address[] memory governors, address[] memory bridgeOperators, uint256[] memory weights);

  /**
   * @dev Returns total weights of the governor list.
   */
  function getSumGovernorWeights(address[] calldata governors) external view returns (uint256 sum);

  /**
   * @dev Returns total weights.
   */
  function getTotalWeights() external view returns (uint256);

  /**
   * @dev Returns an array of all bridge operators.
   * @return An array containing the addresses of all bridge operators.
   */
  function getBridgeOperators() external view returns (address[] memory);

  /**
   * @dev Returns an array of bridge operators correspoding to governor addresses.
   * @return bridgeOperators_ An array containing the addresses of all bridge operators.
   */
  function getBridgeOperatorOf(address[] calldata gorvernors) external view returns (address[] memory bridgeOperators_);

  /**
   * @dev Returns the weight of a bridge voter.
   */
  function getGovernorWeight(address governor) external view returns (uint256);

  /**
   * @dev Returns the weights of a list of bridge voter addresses.
   */
  function getGovernorWeights(address[] memory governors) external view returns (uint256[] memory weights);

  /**
   * @dev Returns an array of all governors.
   * @return An array containing the addresses of all governors.
   */
  function getGovernors() external view returns (address[] memory);

  /**
   * @dev Adds multiple bridge operators.
   * @param governors An array of addresses of hot/cold wallets for bridge operator to update their node address.
   * @param bridgeOperators An array of addresses representing the bridge operators to add.
   * @return addeds An array of booleans indicating whether each bridge operator was added successfully.
   */
  function addBridgeOperators(
    uint256[] calldata voteWeights,
    address[] calldata governors,
    address[] calldata bridgeOperators
  ) external returns (bool[] memory addeds);

  /**
   * @dev Removes multiple bridge operators.
   * @param bridgeOperators An array of addresses representing the bridge operators to remove.
   * @return removeds An array of booleans indicating whether each bridge operator was removed successfully.
   */
  function removeBridgeOperators(address[] calldata bridgeOperators) external returns (bool[] memory removeds);

  /**
   * @dev Governor updates their corresponding governor and/or operator address.
   * Requirements:
   * - The caller must the governor of the operator that is requested changes.
   * @param bridgeOperator The address of the bridge operator to update.
   * @return updated A boolean indicating whether the bridge operator was updated successfully.
   */
  function updateBridgeOperator(address bridgeOperator) external returns (bool updated);
}
