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

  /**
   * @dev Retrieves the full information of all registered bridge operators.
   *
   * This external function allows external callers to obtain the full information of all the registered bridge operators.
   * The returned arrays include the addresses of governors, bridge operators, and their corresponding vote weights.
   *
   * @return governors An array of addresses representing the governors of each bridge operator.
   * @return bridgeOperators An array of addresses representing the registered bridge operators.
   * @return weights An array of uint256 values representing the vote weights of each bridge operator.
   *
   * Note: The length of each array will be the same, and the order of elements corresponds to the same bridge operator.
   *
   * Example Usage:
   * ```
   * (address[] memory governors, address[] memory bridgeOperators, uint256[] memory weights) = getFullBridgeOperatorInfos();
   * for (uint256 i = 0; i < bridgeOperators.length; i++) {
   *     // Access individual information for each bridge operator.
   *     address governor = governors[i];
   *     address bridgeOperator = bridgeOperators[i];
   *     uint256 weight = weights[i];
   *     // ... (Process or use the information as required) ...
   * }
   * ```
   *
   */
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
   * @dev Retrieves the governors corresponding to a given array of bridge operators.
   * This external function allows external callers to obtain the governors associated with a given array of bridge operators.
   * The function takes an input array `bridgeOperators` containing bridge operator addresses and returns an array of corresponding governors.
   * @param bridgeOperators An array of bridge operator addresses for which governors are to be retrieved.
   * @return governors An array of addresses representing the governors corresponding to the provided bridge operators.
   */
  function getGovernorsOf(address[] calldata bridgeOperators) external view returns (address[] memory governors);

  /**
   * @dev Returns the weights of a list of bridge voter addresses.
   */
  function getGovernorWeights(address[] calldata governors) external view returns (uint256[] memory weights);

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
   *
   * Note: return boolean array `addeds` indicates whether a group (voteWeight, governor, operator) are recorded.
   * It is expected that FE/BE staticcall to the function first to get the return values and handle it correctly.
   * Governors are expected to see the outcome of this function and decide if they want to vote for the proposal or not.
   *
   * Example Usage:
   * Making an `eth_call` in ethers.js
   * ```
   * const {addeds} = await bridgeManagerContract.callStatic.addBridgeOperators(
   *  voteWeights,
   *  governors,
   *  bridgeOperators,
   *  // overriding the caller to the contract itself since we use `onlySelfCall` guard
   *  {from: bridgeManagerContract.address}
   * )
   * const filteredOperators = bridgeOperators.filter((_, index) => addeds[index]);
   * const filteredWeights = weights.filter((_, index) => addeds[index]);
   * const filteredGovernors = governors.filter((_, index) => addeds[index]);
   * // ... (Process or use the information as required) ...
   * ```
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
   *
   * * Note: return boolean array `removeds` indicates whether a group (voteWeight, governor, operator) are recorded.
   * It is expected that FE/BE staticcall to the function first to get the return values and handle it correctly.
   * Governors are expected to see the outcome of this function and decide if they want to vote for the proposal or not.
   *
   * Example Usage:
   * Making an `eth_call` in ethers.js
   * ```
   * const {removeds} = await bridgeManagerContract.callStatic.removeBridgeOperators(
   *  bridgeOperators,
   *  // overriding the caller to the contract itself since we use `onlySelfCall` guard
   *  {from: bridgeManagerContract.address}
   * )
   * const filteredOperators = bridgeOperators.filter((_, index) => removeds[index]);
   * // ... (Process or use the information as required) ...
   * ```
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
