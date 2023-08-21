// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IFastFinalityTracking {
  function recordFinality(address[] calldata voters) external;

  function getManyFinalityVoteCounts(
    uint256 period,
    address[] calldata addrs
  ) external view returns (uint256[] memory voteCounts);
}
