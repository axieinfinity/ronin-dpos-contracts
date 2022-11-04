// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface PeriodWrapperConsumer {
  struct PeriodWrapper {
    // Inner value.
    uint256 inner;
    // Last period number that the info updated.
    uint256 lastPeriod;
  }
}
