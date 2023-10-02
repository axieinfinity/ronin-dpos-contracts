// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

abstract contract RuntimeConfig {
  struct Options {
    bool log;
    bool trezor;
  }

  Options internal _options;

  function setRuntimeConfig(Options memory options) external {
    _options = options;
  }

  function getRuntimeConfig() public view returns (Options memory options) {
    options = _options;
  }
}
