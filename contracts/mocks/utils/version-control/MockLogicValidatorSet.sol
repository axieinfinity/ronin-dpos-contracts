// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { GlobalConfigConsumer } from "../../../extensions/consumers/GlobalConfigConsumer.sol";

interface ILogicValidatorSet {
  function wrapUpEpoch() external payable;

  function version() external view returns (string memory);

  function currentPeriod() external view returns (uint256);
}

abstract contract MockLogicValidatorSetCore is ILogicValidatorSet, GlobalConfigConsumer {
  uint256 private _lastUpdatedPeriod;

  function wrapUpEpoch() external payable {
    if (block.number % 100 == 0) {
      _lastUpdatedPeriod += 1;
    }
  }

  function currentPeriod() external view returns (uint256) {
    return _lastUpdatedPeriod;
  }
}

contract MockLogicValidatorSetV1 is MockLogicValidatorSetCore {
  function version() external pure returns (string memory) {
    return "V1";
  }
}

contract MockLogicValidatorSetV2 {
  function version() external pure returns (string memory) {
    return "V2";
  }
}
