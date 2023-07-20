// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../../udvts/Types.sol";

interface IJailingInfo {
  /**
   * @dev Returns whether the validator are put in jail (cannot join the set of validators) during the current period.
   */
  function checkJailed(TConsensus) external view returns (bool);

  /**
   * @dev Returns whether the validator are put in jail and the number of block and epoch that he still is in the jail.
   */
  function getJailedTimeLeft(
    TConsensus addr
  ) external view returns (bool isJailed_, uint256 blockLeft_, uint256 epochLeft_);

  /**
   * @dev Returns whether the validator are put in jail (cannot join the set of validators) at a specific block.
   */
  function checkJailedAtBlock(TConsensus addr, uint256 blockNum) external view returns (bool);

  /**
   * @dev Returns whether the validator are put in jail at a specific block and the number of block and epoch that he still is in the jail.
   */
  function getJailedTimeLeftAtBlock(
    TConsensus addr,
    uint256 blockNum
  ) external view returns (bool isJailed_, uint256 blockLeft_, uint256 epochLeft_);

  /**
   * @dev Returns whether the validators are put in jail (cannot join the set of validators) during the current period.
   */
  function checkManyJailed(TConsensus[] calldata) external view returns (bool[] memory);

  function checkManyJailedById(address[] calldata candidateIds) external view returns (bool[] memory);

  /**
   * @dev Returns whether the incoming reward of the block producer is deprecated during the current period.
   */
  function checkMiningRewardDeprecated(TConsensus addr) external view returns (bool);

  /**
   * @dev Returns whether the incoming reward of the block producer is deprecated during a specific period.
   */
  function checkMiningRewardDeprecatedAtPeriod(TConsensus addr, uint256 period) external view returns (bool);
}
