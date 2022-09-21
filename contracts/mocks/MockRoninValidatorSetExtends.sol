// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../validator/RoninValidatorSet.sol";

contract MockRoninValidatorSetExtends is RoninValidatorSet {
  uint256[] internal _epochs;
  uint256[] internal _periods;

  constructor() {}

  function endEpoch() external {
    _epochs.push(block.number);
  }

  function endPeriod() external {
    _periods.push(block.number);
  }

  function periodOf(uint256 _block) public view override returns (uint256 _period) {
    for (uint256 _i = _periods.length; _i > 0; _i--) {
      if (_block >= _periods[_i - 1]) {
        return _i;
      }
    }
  }

  function epochOf(uint256 _block) public view override returns (uint256 _epoch) {
    for (uint256 _i = _epochs.length; _i > 0; _i--) {
      if (_block >= _epochs[_i - 1]) {
        return _i;
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

  function getJailUntils(address[] calldata _addrs) public view returns (uint256[] memory jailUntils_) {
    jailUntils_ = new uint256[](_addrs.length);
    for (uint _i = 0; _i < _addrs.length; _i++) {
      jailUntils_[_i] = _jailedUntil[_addrs[_i]];
    }
  }

  function arrangeValidatorCandidates(address[] memory _candidates, uint _newValidatorCount)
    external
    view
    returns (address[] memory)
  {
    _arrangeValidatorCandidates(_candidates, _newValidatorCount);

    assembly {
      mstore(_candidates, _newValidatorCount)
    }

    return _candidates;
  }
}
