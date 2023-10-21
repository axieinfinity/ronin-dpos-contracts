// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILogicValidatorSet {
  event Received(string version);

  function wrapUpEpoch() external payable;

  function version() external view returns (string memory);

  function currentPeriod() external view returns (uint256);
}

abstract contract MockLogicValidatorSetCore is ILogicValidatorSet {
  uint256 private _lastUpdatedPeriod;

  receive() external payable virtual {
    emit Received("0");
  }

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
  receive() external payable override {
    emit Received(version());
  }

  function version() public pure returns (string memory) {
    return "V1";
  }
}

contract MockLogicValidatorSetV2 is MockLogicValidatorSetCore {
  receive() external payable override {
    emit Received(version());
  }

  function version() public pure returns (string memory) {
    return "V2";
  }
}
