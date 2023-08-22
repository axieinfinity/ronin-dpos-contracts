// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17 <0.9.0;

contract MockValidatorSet {
  uint256 _period;

  function setPeriod(uint256 period) external {
    _period = period;
  }

  function currentPeriod() external view returns (uint256) {
    return _period;
  }
}
