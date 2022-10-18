// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../interfaces/IBridge.sol";

contract MockBridge is IBridge {
  WeightedAddress[] public bridgeOperators;

  function replaceBridgeOperators(WeightedAddress[] calldata _list) external override {
    while (bridgeOperators.length > 0) {
      bridgeOperators.pop();
    }
    for (uint _i = 0; _i < _list.length; _i++) {
      bridgeOperators.push(_list[_i]);
    }
  }

  function getBridgeOperators() external view override returns (WeightedAddress[] memory) {
    return bridgeOperators;
  }
}
