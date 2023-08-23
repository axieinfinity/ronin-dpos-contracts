// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IFastFinalityTracking {
  /**
   * @dev Submit list of `voters` who vote for fast finality in the current block.
   *
   * Requirements:
   * - Only called once per block
   * - Only coinbase can call this method
   */
  function recordFinality(address[] calldata voters) external;

  /**
   * @dev Returns vote count of `addrs` in the `period`.
   */
  function getManyFinalityVoteCounts(
    uint256 period,
    address[] calldata addrs
  ) external view returns (uint256[] memory voteCounts);
}
