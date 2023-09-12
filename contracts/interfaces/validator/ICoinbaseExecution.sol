// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./ISlashingExecution.sol";

interface ICoinbaseExecution is ISlashingExecution {
  enum BlockRewardDeprecatedType {
    UNKNOWN,
    UNAVAILABILITY,
    AFTER_BAILOUT
  }

  /// @dev Emitted when the validator set is updated
  event ValidatorSetUpdated(uint256 indexed period, address[] consensusAddrs);
  /// @dev Emitted when the bridge operator set is updated, to mirror the in-jail and maintaining status of the validator.
  event BlockProducerSetUpdated(uint256 indexed period, uint256 indexed epoch, address[] consensusAddrs);
  /// @dev Emitted when the bridge operator set is updated.
  event BridgeOperatorSetUpdated(uint256 indexed period, uint256 indexed epoch, address[] bridgeOperators);

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

  /// @dev Emitted when the fast finality reward is distributed.
  event FastFinalityRewardDistributed(address indexed consensusAddr, address indexed recipient, uint256 amount);
  /// @dev Emitted when the contract fails when distributing the fast finality reward.
  event FastFinalityRewardDistributionFailed(
    address indexed consensusAddr,
    address indexed recipient,
    uint256 amount,
    uint256 contractBalance
  );

  /// @dev Emitted when the amount of RON reward is distributed to staking contract.
  event StakingRewardDistributed(uint256 totalAmount, address[] consensusAddrs, uint256[] amounts);
  /// @dev Emitted when the contracts fails when distributing the amount of RON to the staking contract.
  event StakingRewardDistributionFailed(
    uint256 totalAmount,
    address[] consensusAddrs,
    uint256[] amounts,
    uint256 contractBalance
  );

  /// @dev Emitted when the epoch is wrapped up.
  event WrappedUpEpoch(uint256 indexed periodNumber, uint256 indexed epochNumber, bool periodEnding);

  /// @dev Error of only allowed at the end of epoch
  error ErrAtEndOfEpochOnly();
  /// @dev Error of query for already wrapped up epoch
  error ErrAlreadyWrappedEpoch();

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
}
