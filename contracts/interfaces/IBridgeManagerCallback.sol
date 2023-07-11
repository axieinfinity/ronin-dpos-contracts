// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBridgeManagerCallback {
  function onBridgeOperatorsAdded(
    address[] memory bridgeOperators,
    bool[] memory addeds
  ) external returns (bytes4 selector);

  function onBridgeOperatorsRemoved(
    address[] memory bridgeOperators,
    bool[] memory removeds
  ) external returns (bytes4 selector);

  function onBridgeOperatorUpdated(
    address currentBridgeOperator,
    address newbridgeOperator,
    bool updated
  ) external returns (bytes4 selector);
}
