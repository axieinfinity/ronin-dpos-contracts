// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./MockRoninValidatorSetOverridePrecompile.sol";
import "../../libraries/EnumFlags.sol";

contract MockRoninValidatorSetExtended is MockRoninValidatorSetOverridePrecompile {
  bool private _initialized;
  uint256[] internal _epochs;

  constructor() {}

  function initEpoch() public {
    if (!_initialized) {
      _epochs.push(0);
      _initialized = true;
    }
  }

  function endEpoch() external {
    _epochs.push(block.number);
  }

  function epochOf(uint256 _block) public view override returns (uint256 _epoch) {
    for (uint256 _i = _epochs.length; _i > 0; _i--) {
      if (_block > _epochs[_i - 1]) {
        return _i;
      }
    }
  }

  function epochEndingAt(uint256 _block) public view override(ITimingInfo, TimingStorage) returns (bool) {
    for (uint _i = 0; _i < _epochs.length; _i++) {
      if (_block == _epochs[_i]) {
        return true;
      }
    }
    return false;
  }

  function getJailUntils(address[] calldata _addrs) public view returns (uint256[] memory jailUntils_) {
    jailUntils_ = new uint256[](_addrs.length);
    for (uint _i = 0; _i < _addrs.length; _i++) {
      jailUntils_[_i] = _blockProducerJailedBlock[_addrs[_i]];
    }
  }

  function addValidators(address[] calldata _addrs) public {
    for (uint _i = 0; _i < _addrs.length; _i++) {
      _validators[_i] = _addrs[_i];
      _validatorMap[_addrs[_i]] = EnumFlags.ValidatorFlag.Both;
    }
  }
}
