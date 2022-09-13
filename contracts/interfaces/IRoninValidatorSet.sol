// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./ISlashIndicator.sol";

interface IRoninValidatorSet {
  /// @dev Emitted when the reward of the valdiator is deprecated.
  event RewardDeprecated(address coinbaseAddr, uint256 rewardAmount);
  /// @dev Emitted when the block reward is submitted.
  event BlockRewardSubmitted(address coinbaseAddr, uint256 rewardAmount);
  /// @dev Emitted when the validator is slashed.
  event ValidatorSlashed(address validatorAddr, uint256 jailedUntil, uint256 deductedStakingAmount);
  /// @dev Emitted when the validator reward is distributed.
  event MiningRewardDistributed(address validatorAddr, uint256 amount);
  /// @dev Emitted when the amount of RON reward is distributed.
  event StakingRewardDistributed(uint256 amount);
  /// @dev Emitted when the validator set is updated
  event ValidatorSetUpdated(address[]);
  /// @dev Emitted when the address of governance admin is updated.
  event GovernanceAdminUpdated(address);
  /// @dev Emitted when the number of max validator is updated
  event MaxValidatorNumberUpdated(uint256);
  /// @dev Emitted when the number of blocks in epoch is updated
  event NumberOfBlocksInEpochUpdated(uint256);
  /// @dev Emitted when the number of epochs in period is updated
  event NumberOfEpochsInPeriodUpdated(uint256);

  ///////////////////////////////////////////////////////////////////////////////////////
  //                              FUNCTIONS FOR COINBASE                               //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Submits reward of the current block.
   *
   * Requirements:
   * - The method caller is coinbase.
   *
   * Emits the event `RewardDeprecated` if the coinbase is slashed or no longer be a validator.
   * Emits the event `BlockRewardSubmitted` for the valid call.
   *
   */
  function submitBlockReward() external payable;

  /**
   * @dev Wraps up the current epoch.
   *
   * Requirements:
   * - The method must be called when the current epoch is ending.
   * - The epoch is not wrapped yet.
   * - The method caller is coinbase.
   *
   * Emits the event `MiningRewardDistributed` when some validator has reward distributed.
   * Emits the event `StakingRewardDistributed` when some staking pool has reward distributed.
   * Emits the event `ValidatorSetUpdated`.
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
   * @dev Returns the governance admin address.
   */
  function governanceAdmin() external view returns (address);

  /**
   * @dev Returns the slash indicator contract address.
   */
  function slashIndicatorContract() external view returns (address);

  /**
   * @dev Returns the staking contract address.
   */
  function stakingContract() external view returns (address);

  /**
   * @dev Slashes the validator.
   *
   * Requirements:
   * - The method caller is slash indicator contract.
   *
   * Emits the event `ValidatorSlashed`.
   *
   */
  function slash(
    address _validatorAddr,
    uint256 _newJailedUntil,
    uint256 _slashAmount
  ) external;

  /**
   * @dev Returns whether the validators are put in jail (cannot join the set of validators) during the current period.
   */
  function jailed(address[] memory) external view returns (bool[] memory);

  /**
   * @dev Returns whether the incoming reward of the validators are deprecated during the period.
   */
  function rewardDeprecated(address[] memory, uint256 _period) external view returns (bool[] memory);

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
   * @dev Returns the maximum number of validators in the epoch
   */
  function maxValidatorNumber() external view returns (uint256 _maximumValidatorNumber);

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

  ///////////////////////////////////////////////////////////////////////////////////////
  //                         FUNCTIONS FOR GOVERNANCE ADMIN                            //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Updates the governance admin
   *
   * Requirements:
   * - The method caller is the governance admin
   *
   * Emits the event `GovernanceAdminUpdated`
   *
   */
  function setGovernanceAdmin(address _governanceAdmin) external;

  /**
   * @dev Updates the max validator number
   *
   * Requirements:
   * - The method caller is the governance admin
   *
   * Emits the event `MaxValidatorNumberUpdated`
   *
   */
  function setMaxValidatorNumber(uint256 _maxValidatorNumber) external;

  /**
   * @dev Updates the number of blocks in epoch
   *
   * Requirements:
   * - The method caller is the governance admin
   *
   * Emits the event `NumberOfBlocksInEpochUpdated`
   *
   */
  function setNumberOfBlocksInEpoch(uint256 _numberOfBlocksInEpoch) external;

  /**
   * @dev Updates the number of epochs in period
   *
   * Requirements:
   * - The method caller is the governance admin
   *
   * Emits the event `NumberOfEpochsInPeriodUpdated`
   *
   */
  function setNumberOfEpochsInPeriod(uint256 _numberOfEpochsInPeriod) external;
}
