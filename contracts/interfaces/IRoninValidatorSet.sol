// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./ICandidateManager.sol";

interface IRoninValidatorSet is ICandidateManager {
  enum BlockRewardDeprecatedType {
    UNKNOWN,
    SLASHED,
    AFTER_BAILOUT
  }

  /// @dev Emitted when the number of max validator is updated
  event MaxValidatorNumberUpdated(uint256);
  /// @dev Emitted when the number of reserved slots for prioritized validators is updated
  event MaxPrioritizedValidatorNumberUpdated(uint256);
  /// @dev Emitted when the number of blocks in epoch is updated
  event NumberOfBlocksInEpochUpdated(uint256);
  /// @dev Emitted when the validator set is updated
  event ValidatorSetUpdated(uint256 indexed period, address[] consensusAddrs);
  /// @dev Emitted when the bridge operator set is updated, to mirror the in-jail and maintaining status of the validator.
  event BlockProducerSetUpdated(uint256 indexed period, address[] consensusAddrs);
  /// @dev Emitted when the bridge operator set is updated.
  event BridgeOperatorSetUpdated(uint256 indexed period, address[] bridgeOperators);

  /// @dev Emitted when the validator is punished.
  event ValidatorPunished(
    address indexed consensusAddr,
    uint256 indexed period,
    uint256 jailedUntil,
    uint256 deductedStakingAmount,
    bool blockProducerRewardDeprecated,
    bool bridgeOperatorRewardDeprecated
  );
  /// @dev Emitted when the validator get out of jail by bailout.
  event ValidatorLiberated(address indexed validator, uint256 period);
  /// @dev Emitted when the reward of the block producer is deprecated.
  event BlockRewardDeprecated(
    address indexed coinbaseAddr,
    uint256 rewardAmount,
    BlockRewardDeprecatedType deprecatedType
  );
  /// @dev Emitted when the block reward is submitted.
  event BlockRewardSubmitted(address indexed coinbaseAddr, uint256 submittedAmount, uint256 bonusAmount);

  /// @dev Emitted when the block producer reward is distributed.
  event MiningRewardDistributed(address indexed consensusAddr, address indexed recipient, uint256 amount);
  /// @dev Emitted when the contract fails when distributing the block producer reward.
  event MiningRewardDistributionFailed(
    address indexed consensusAddr,
    address indexed recipient,
    uint256 amount,
    uint256 contractBalance
  );

  /// @dev Emitted when the bridge operator reward is distributed.
  event BridgeOperatorRewardDistributed(
    address indexed consensusAddr,
    address indexed bridgeOperator,
    address indexed recipientAddr,
    uint256 amount
  );
  /// @dev Emitted when the contract fails when distributing the bridge operator reward.
  event BridgeOperatorRewardDistributionFailed(
    address indexed consensusAddr,
    address indexed bridgeOperator,
    address indexed recipient,
    uint256 amount,
    uint256 contractBalance
  );

  /// @dev Emitted when the amount of RON reward is distributed to staking contract.
  event StakingRewardDistributed(uint256 amount);
  /// @dev Emitted when the contracts fails when distributing the amount of RON to the staking contract.
  event StakingRewardDistributionFailed(uint256 amount, uint256 contractBalance);

  /// @dev Emitted when the epoch is wrapped up.
  event WrappedUpEpoch(uint256 indexed periodNumber, uint256 indexed epochNumber, bool periodEnding);

  ///////////////////////////////////////////////////////////////////////////////////////
  //                              FUNCTIONS FOR COINBASE                               //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Submits reward of the current block.
   *
   * Requirements:
   * - The method caller is coinbase.
   *
   * Emits the event `MiningRewardDeprecated` if the coinbase is slashed or no longer be a block producer.
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
   * Emits the event `BlockProducerSetUpdated` when the epoch is wrapped up.
   * Emits the event `BridgeOperatorSetUpdated` when the epoch is wrapped up at period ending.
   * Emits the event `ValidatorSetUpdated` when the epoch is wrapped up at period ending, and the validator set gets updated.
   * Emits the event `WrappedUpEpoch`.
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
   * @dev Slashes the validator.
   *
   * Requirements:
   * - The method caller is slash indicator contract.
   *
   * Emits the event `ValidatorPunished`.
   *
   */
  function slash(
    address _validatorAddr,
    uint256 _newJailedUntil,
    uint256 _slashAmount
  ) external;

  /**
   * @dev Bailout the validator.
   *
   * Requirements:
   * - The method caller is slash indicator contract.
   *
   * Emits the event `ValidatorLiberated`.
   *
   */
  function bailOut(address _validatorAddr, uint256 _period) external;

  /**
   * @dev Returns whether the validator are put in jail (cannot join the set of validators) during the current period.
   */
  function jailed(address) external view returns (bool);

  /**
   * @dev Returns whether the validator are put in jail and the number of block and epoch that he still is in the jail.
   */
  function jailedTimeLeft(address _addr)
    external
    view
    returns (
      bool isJailed_,
      uint256 blockLeft_,
      uint256 epochLeft_
    );

  /**
   * @dev Returns whether the validator are put in jail (cannot join the set of validators) at a specific block.
   */
  function jailedAtBlock(address _addr, uint256 _blockNum) external view returns (bool);

  /**
   * @dev Returns whether the validator are put in jail at a specific block and the number of block and epoch that he still is in the jail.
   */
  function jailedTimeLeftAtBlock(address _addr, uint256 _blockNum)
    external
    view
    returns (
      bool isJailed_,
      uint256 blockLeft_,
      uint256 epochLeft_
    );

  /**
   * @dev Returns whether the validators are put in jail (cannot join the set of validators) during the current period.
   */
  function bulkJailed(address[] memory) external view returns (bool[] memory);

  /**
   * @dev Returns whether the incoming reward of the block producers are deprecated during the current period.
   */
  function miningRewardDeprecated(address[] memory _blockProducers) external view returns (bool[] memory);

  /**
   * @dev Returns whether the incoming reward of the block producers are deprecated during a specific period.
   */
  function miningRewardDeprecatedAtPeriod(address[] memory _blockProducers, uint256 _period)
    external
    view
    returns (bool[] memory);

  ///////////////////////////////////////////////////////////////////////////////////////
  //                             FUNCTIONS FOR NORMAL USER                             //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Returns the maximum number of validators in the epoch
   */
  function maxValidatorNumber() external view returns (uint256 _maximumValidatorNumber);

  /**
   * @dev Returns the number of reserved slots for prioritized validators
   */
  function maxPrioritizedValidatorNumber() external view returns (uint256 _maximumPrioritizedValidatorNumber);

  /**
   * @dev Returns the epoch index from the block number.
   */
  function epochOf(uint256 _block) external view returns (uint256);

  /**
   * @dev Returns the current validator list.
   */
  function getValidators() external view returns (address[] memory);

  /**
   * @dev Returns whether the address is either a bridge operator or a block producer.
   */
  function isValidator(address _addr) external view returns (bool);

  /**
   * @dev Returns the current block producer list.
   */
  function getBlockProducers() external view returns (address[] memory);

  /**
   * @dev Returns whether the address is block producer or not.
   */
  function isBlockProducer(address _addr) external view returns (bool);

  /**
   * @dev Returns total numbers of the block producers.
   */
  function totalBlockProducers() external view returns (uint256);

  /**
   * @dev Returns the current bridge operator list.
   */
  function getBridgeOperators() external view returns (address[] memory);

  /**
   * @dev Returns whether the address is bridge operator or not.
   */
  function isBridgeOperator(address _addr) external view returns (bool);

  /**
   * @dev Returns total numbers of the bridge operators.
   */
  function totalBridgeOperators() external view returns (uint256);

  /**
   * @dev Returns whether the epoch ending is at the block number `_block`.
   */
  function epochEndingAt(uint256 _block) external view returns (bool);

  /**
   * @dev Returns whether the period ending at the current block number.
   */
  function isPeriodEnding() external view returns (bool);

  ///////////////////////////////////////////////////////////////////////////////////////
  //                               FUNCTIONS FOR ADMIN                                 //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Updates the max validator number
   *
   * Requirements:
   * - The method caller is admin
   *
   * Emits the event `MaxValidatorNumberUpdated`
   *
   */
  function setMaxValidatorNumber(uint256 _maxValidatorNumber) external;

  /**
   * @dev Updates the number of blocks in epoch
   *
   * Requirements:
   * - The method caller is admin
   *
   * Emits the event `NumberOfBlocksInEpochUpdated`
   *
   */
  function setNumberOfBlocksInEpoch(uint256 _numberOfBlocksInEpoch) external;
}
