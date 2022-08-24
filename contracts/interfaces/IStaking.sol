// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IStaking {
  struct ValidatorCandidate {
    /// @dev Address that stakes for the validator, each consensus address has only one staking address.
    address stakingAddr;
    /// @dev Address of the validator that produces block, e.g. block.coinbase. This is so-called validator address.
    address consensusAddr;
    /// @dev Address that receives mining fee of the validator
    address payable treasuryAddr;
    /// @dev The percentile of reward that validators can be received, the rest goes to the delegators
    uint256 commissionRate;
    /// @dev The RON amount from the validator.
    uint256 stakedAmount;
    /// @dev The RON amount from the delegator.
    uint256 delegatedAmount;
    /// @dev For upgrability purpose
    uint256[20] ____gap;
  }

  /// @dev TODO: add comment for these events
  event ValidatorProposed(
    address indexed consensusAddr,
    address indexed candidateIdx,
    uint256 amount,
    ValidatorCandidate _info
  );
  event Staked(address indexed validator, uint256 amount);
  event Unstaked(address indexed validator, uint256 amount);
  event Delegated(address indexed delegator, address indexed validator, uint256 amount);
  event Undelegated(address indexed delegator, address indexed validator, uint256 amount);

  // TODO: write comment for this fn.
  // TODO: write setter for this fn.
  function minValidatorBalance() external view returns (uint256);

  /**
   * @dev Proposes a validator with detailed information.
   *
   * Requirements:
   * - The `msg.value` is at least `MINIMUM_STAKING` amount.
   * - TODO: update the requirements.
   *
   * Emits the `ValidatorProposed` event.
   *
   * @return index The index of new validator in the validator list
   *
   */
  function proposeValidator(
    address _consensusAddr,
    address payable _treasuryAddr,
    uint256 _commissionRate
  ) external payable returns (uint256 index);

  /**
   * @notice Stake as validator.
   */
  function stake(uint256 amount) external payable;

  /**
   * @notice Unstake as validator. Need to wait `UNSTAKING_ON_HOLD_BLOCKS_NUM` blocks.
   * @dev The remain balance must either be greater than `MINIMUM_STAKING` value or equal to zero.
   */
  function unstake(address consensusAddr, uint256 amount) external;

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
   * @dev Sorting the validators by their current balance, then pick the top N validators to be
   * assigned to the new set. The result is returned to the `ValidatorSet` contract.
   *
   * Requirements:
   * - Only validator and `ValidatorSet` contract can call this function
   * 
   * @return newValidatorSet Validator set for the new epoch
   */
  function updateValidatorSet() external returns (ValidatorCandidate[] memory newValidatorSet);

  /**
   * @dev Handle deposit request. Update validators' reward balance and delegators' balance.
   *
   * Requirements:
   * - Only `ValidatorSet` contract cann call this function
   */
  function onDeposit() external payable;

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
