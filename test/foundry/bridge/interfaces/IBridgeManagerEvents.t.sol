// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBridgeManagerEventsTest {
  struct BridgeOperatorInfo {
    address addr;
    uint96 voteWeight;
  }

  event BridgeOperatorsAdded(bool[] statuses, uint96[] voteWeights, address[] governors, address[] bridgeOperators);

  event BridgeOperatorsRemoved(bool[] statuses, address[] bridgeOperators);

  event BridgeOperatorUpdated(
    address indexed governor,
    address indexed fromBridgeOperator,
    address indexed toBridgeOperator
  );
}
