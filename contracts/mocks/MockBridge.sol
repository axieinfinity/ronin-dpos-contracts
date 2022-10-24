// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../interfaces/IBridge.sol";

contract MockBridge is IBridge {
  address[] public bridgeOperators;

  function replaceBridgeOperators(address[] calldata _list) external override {
    while (bridgeOperators.length > 0) {
      bridgeOperators.pop();
    }
    for (uint _i = 0; _i < _list.length; _i++) {
      bridgeOperators.push(_list[_i]);
    }
  }

  function getBridgeOperators() external view override returns (address[] memory) {
    return bridgeOperators;
  }
}
