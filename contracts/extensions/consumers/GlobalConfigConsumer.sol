// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

abstract contract GlobalConfigConsumer {
  /// The addition amount of gas stipend send along in external calls.
  uint256 public constant DEFAULT_ADDITION_GAS = 3500;
  /// @dev The length of a period in second.
  uint256 public constant PERIOD_DURATION = 1 days;
}
