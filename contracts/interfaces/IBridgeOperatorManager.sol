// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IBridgeOperatorManager
 * @dev The interface for managing bridge operators.
 */
interface IBridgeOperatorManager {
  struct BridgeOperatorInfo {
    address addr;
    uint96 voteWeight;
  }

  event BridgeOperatorsAdded(
    address indexed operator,
    bool[] statuses,
    uint256[] voteWeights,
    address[] governors,
    address[] bridgeOperators
  );

  event BridgeOperatorsRemoved(address indexed operator, bool[] statuses, address[] bridgeOperators);

  event BridgeOperatorUpdated(
    address indexed operator,
    address indexed fromBridgeOperator,
    address indexed toBridgeOperator
  );

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
   * @dev Returns total weights of the bridge voter list.
   */
  function getSumBridgeVoterWeights(address[] calldata governors) external view returns (uint256 sum);

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
  function getBridgeVoterWeight(address governor) external view returns (uint256);

  /**
   * @dev Returns the weights of a list of bridge voter addresses.
   */
  function getBridgeVoterWeights(address[] calldata governors) external view returns (uint256[] memory weights);

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
   * @dev Updates a bridge operator.
   * @param bridgeOperator The address of the bridge operator to update.
   * @return updated A boolean indicating whether the bridge operator was updated successfully.
   */
  function updateBridgeOperator(address bridgeOperator) external returns (bool updated);
}
