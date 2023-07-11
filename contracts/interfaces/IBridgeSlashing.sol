// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBridgeSlashing {
  enum Tier {
    Tier0,
    Tier1,
    Tier2
  }

  event Slashed(Tier indexed tier, address indexed bridgeOperator, uint256 indexed period, uint256 until);

  function slashUnavailability(uint256 period) external;

  function penalizeDurationOf(address[] calldata bridgeOperators) external returns (uint256[] memory durations);
}
