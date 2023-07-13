// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockValidatorContract {
  uint256 private _currentPeriod;

  function currentPeriod() external view returns (uint256) {
    return _currentPeriod;
  }

  function setCurrentPeriod(uint256 period) external {
    _currentPeriod = period;
  }
}
