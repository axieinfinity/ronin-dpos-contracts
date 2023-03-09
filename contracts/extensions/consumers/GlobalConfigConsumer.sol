// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

abstract contract GlobalConfigConsumer {
  /// @dev The addition amount of gas sending along in external calls. Total gas stipend is added with default 2300 gas.
  uint256 public constant DEFAULT_ADDITION_GAS = 1200;
  /// @dev The length of a period in second.
  uint256 public constant PERIOD_DURATION = 1 days;
}
