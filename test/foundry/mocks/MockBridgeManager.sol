// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17 <0.9.0;

import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";

contract MockBridgeManager is IBridgeManager {
  function DOMAIN_SEPARATOR() external view returns (bytes32) {}

  function addBridgeOperators(
    uint96[] calldata voteWeights,
    address[] calldata governors,
    address[] calldata bridgeOperators
  ) external returns (bool[] memory addeds) {}

  function getBridgeOperatorOf(
    address[] calldata gorvernors
  ) external view returns (address[] memory bridgeOperators_) {}

  function getBridgeOperatorWeight(address bridgeOperator) external view returns (uint96 weight) {}

  function getBridgeOperators() external view returns (address[] memory) {}

  function getFullBridgeOperatorInfos()
    external
    view
    returns (address[] memory governors, address[] memory bridgeOperators, uint96[] memory weights)
  {}

  function getGovernorWeight(address governor) external view returns (uint96) {}

  function getGovernorWeights(address[] calldata governors) external view returns (uint96[] memory weights) {}

  function getGovernors() external view returns (address[] memory) {}

  function getGovernorsOf(address[] calldata bridgeOperators) external view returns (address[] memory governors) {}

  function getTotalWeight() external view returns (uint256) {}

  function isBridgeOperator(address addr) external view returns (bool) {}

  function removeBridgeOperators(address[] calldata bridgeOperators) external returns (bool[] memory removeds) {}

  function sumGovernorsWeight(address[] calldata governors) external view returns (uint256 sum) {}

  function totalBridgeOperator() external view returns (uint256) {}

  function updateBridgeOperator(address bridgeOperator) external {}
}
