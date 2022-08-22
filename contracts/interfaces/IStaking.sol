// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IStaking {
  struct ValidatorInfo {
    /// @dev Address of the validator that produces block, e.g. block.coinbase. This is so-called validator address.
    address consensusAddress;
    /// @dev Address that stakes for the validator, each consensus address has only one staking address
    address stakingAddress;
    /// @dev Address that receives mining fee of the validator
    address payable feeAddress;
    /// @dev Total reward amount
    uint256 totalReward;
    /// @dev The percentile of reward that delegators can be received
    uint256 commissionRate;
    /// @dev The amount of staked coin in the previous epoch
    uint256 staked;
    /// @dev The difference between the amount of staked coin in the previous epoch and the current epoch
    int256 stakedDiff;
    /// @dev Sum of staked amount from validator and delegators
    uint256 balance;
    /// @dev Last staking block number, used for calculating time condition of unstaking
    uint256 lastStakingBlock;
    /// @dev For upgrability purpose
    uint256[20] ____gap;
  }

  struct DelegatorInfo {
    /// @dev Total amount of delegated token
    uint256 balance;
    uint256 totalReward;
    uint256 pendingReward;
    /// @dev Delegating amount of delegator for each validator (validator consensus address => amount)
    mapping(address => uint256) delegatedOfValidator;
    /// @dev For upgrability purpose
    uint256[20] ____gap;
  }

  /**
   * @notice First proposing a validator with information, require to stake at least `MINIMUM_STAKING` amount
   *
   * @return index The index of new validator in the validator list
   */
  function proposeValidator(
    address consensusAddress,
    address payable feeAddress,
    uint256 commissionRate,
    uint256 amount
  ) external payable returns (uint256 index);

  /**
   * @notice Stake as validator.
   */
  function stake(address consensusAddress, uint256 amount) external payable;

  /**
   * @notice Unstake as validator. Need to wait `UNSTAKING_ON_HOLD_BLOCKS_NUM` blocks.
   * @dev The remain balance must either be greater than `MINIMUM_STAKING` value or equal to zero.
   */
  function unstake(address consensusAddress, uint256 amount) external;

  /**
   * @notice Stake as delegator	for a validator
   *
   * @dev Each delegator can stake token to many validators. Upon each delegation, the following
   * actions are done:
   * - Update staking balance of delegator for corresponding validator
   * - Update staking balance of delegator
   * - Not update `balance` of validator
   * - Update `stakedDiff` of validator to record and update into `balance` at the end of each
   * epoch in `updateValidatorSet()`
   */
  function delegate(address validatorAddress, uint256 amount) external payable;

  /**
   * @notice Unstake as delegator	for a validator
   */
  function undelegate(address user, uint256 amount) external;

  /**
   * @notice Update set of validators
   *
   * @dev Add stake and stake_diff for each validator. Obtain currentValidatorSet based on validators
   *
   * Requirements:
   * - Only validator and `ValidatorSet` contract can call this function
   */
  function updateValidatorSet() external;

  /**
   * @notice Distribute reward
   *
   * @dev Allocate reward based on staked coins of delegators pendingReward.
   *
   * Requirements:
   * - Only validator can call this function
   */
  function allocateReward(address valAddr, uint256 amount) external;

  /**
   * @notice Distribute reward
   *
   * @dev	Get the reward from Validator.sol contract. Update pendingReward to claimableReward.
   *
   * Requirements:
   * - Only validator can call this function
   */
  function receiveReward(address valAddr) external payable;

  /**
   * @notice Delegators call this method to claim their pending rewards
   */
  function claimReward(uint256 amount) external;

  /**
   * @notice Reduce amount stake from the validator.
   *
   * Requirements:
   * - Only validators or Validator contract can call this function
   */
  function slash(address valAddr, uint256 amount) external;
}
