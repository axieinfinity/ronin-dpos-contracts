// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../ronin-validator/RoninValidatorSet.sol";

contract MockRoninValidatorSetEpochSetter is RoninValidatorSet {
  uint256[] internal _epochs;
  uint256[] internal _periods;

  constructor(
    address __governanceAdminContract,
    address __slashIndicatorContract,
    address __stakingContract,
    uint256 __maxValidatorNumber
  ) {
    _governanceAdminContract = __governanceAdminContract;
    _slashIndicatorContract = __slashIndicatorContract;
    _stakingContract = __stakingContract;
    _maxValidatorNumber = __maxValidatorNumber;
  }

  function endEpoch() external {
    _epochs.push(block.number);
  }

  function endPeriod() external {
    _periods.push(block.number);
  }

  function periodOf(uint256 _block) public view override returns (uint256 _period) {
    for (uint256 _i; _i < _periods.length; _i++) {
      if (_block >= _periods[_i]) {
        _period = _i + 1;
      }
    }
  }

  function epochOf(uint256 _block) public view override returns (uint256 _epoch) {
    for (uint256 _i; _i < _epochs.length; _i++) {
      if (_block >= _epochs[_i]) {
        _epoch = _i + 1;
      }
    }
  }

  function epochEndingAt(uint256 _block) public view override returns (bool) {
    for (uint _i = 0; _i < _epochs.length; _i++) {
      if (_block == _epochs[_i]) {
        return true;
      }
    }
    return false;
  }

  function periodEndingAt(uint256 _block) public view override returns (bool) {
    for (uint _i = 0; _i < _periods.length; _i++) {
      if (_block == _periods[_i]) {
        return true;
      }
    }
    return false;
  }
}
