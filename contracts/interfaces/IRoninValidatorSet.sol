// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./ISlashIndicator.sol";

interface IRoninValidatorSet {
  ///////////////////////////////////////////////////////////////////////////////////////
  //                              FUNCTIONS FOR COINBASE                               //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Submits reward of the current block.
   *
   * Requirements:
   * - The method caller is coinbase.
   *
   */
  function submitBlockReward() external payable;

  /**
   * @dev Wraps up the current epoch.
   *
   * Requirements:
   * - The method caller is coinbase.
   *
   */
  function wrapUpEpoch() external payable;

  /**
   * @dev Returns the block that validator set was updated.
   */
  function getLastUpdatedBlock() external view returns (uint256);

  ///////////////////////////////////////////////////////////////////////////////////////
  //                            FUNCTIONS FOR SLASH INDICATOR                          //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Returns the governance admin contract address.
   */
  function governanceAdminContract() external view returns (address);

  /**
   * @dev Returns the slash indicator contract address.
   */
  function slashIndicatorContract() external view returns (address);

  /**
   * @dev Returns the staking contract address.
   */
  function stakingContract() external view returns (address);

  /* @dev Slashes the validator that missed 50 block a day
   *
   * Requirements:
   * - The method caller is slash indicator contract.
   *
   */
  function slashMisdemeanor(address _validatorAddr) external;

  /**
   * @dev Slashes the validator that missed 150 block a day
   *
   * Requirements:
   * - The method caller is slash indicator contract.
   *
   */
  function slashFelony(address _validatorAddr) external;

  /**
   * @dev Slashes the validator that created 2 blocks on a same height
   *
   * Requirements:
   * - The method caller is slash indicator contract.
   *
   */
  function slashDoubleSign(address _validatorAddr) external;

  /**
   * @dev Returns whether the validators are put in jail (cannot join the set of validators) during the current period.
   */
  function jailed(address[] memory) external view returns (bool[] memory);

  /**
   * @dev Returns whether the incoming reward of the validators are sinked during the period.
   */
  function noPendingReward(address[] memory, uint256 _period) external view returns (bool[] memory);

  /**
   * @dev The amount of RON to slash felony.
   */
  function slashFelonyAmount() external view returns (uint256);

  /**
   * @dev The amount of RON to slash felony.
   */
  function slashDoubleSignAmount() external view returns (uint256);

  ///////////////////////////////////////////////////////////////////////////////////////
  //                             FUNCTIONS FOR NORMAL USER                             //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Returns the number of epochs in a period.
   */
  function numberOfEpochsInPeriod() external view returns (uint256 _numberOfEpochs);

  /**
   * @dev Returns the number of blocks in a epoch.
   */
  function numberOfBlocksInEpoch() external view returns (uint256 _numberOfBlocks);

  /**
   * @dev Returns the epoch index from the block number.
   */
  function epochOf(uint256 _block) external view returns (uint256);

  /**
   * @dev Returns the period index from the block number.
   */
  function periodOf(uint256 _block) external view returns (uint256);

  /**
   * @dev Returns the current validator list.
   */
  function getValidators() external view returns (address[] memory);

  /**
   * @dev Returns whether the epoch ending is at the block number `_block`.
   */
  function epochEndingAt(uint256 _block) external view returns (bool);

  /**
   * @dev Returns whether the period ending is at the block number `_block`.
   */
  function periodEndingAt(uint256 _block) external view returns (bool);
}
