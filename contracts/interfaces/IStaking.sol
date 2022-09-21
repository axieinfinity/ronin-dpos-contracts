// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IRewardPool.sol";

interface IStaking is IRewardPool {
  struct PoolDetail {
    // Address of the pool
    address addr;
    // Pool admin address
    address admin;
    // Self-staked amount
    uint256 stakedAmount;
    // Total balance of the pool
    uint256 totalBalance;
    // Mapping from delegator => delegated amount
    mapping(address => uint256) delegatedAmount;
  }

  event ValidatorPoolAdded(address indexed validator, address indexed admin);
  /// @dev Emitted when the validator candidate requested to renounce.
  event ValidatorRenounceRequested(address indexed consensusAddr, uint256 amount);
  /// @dev Emitted when the renounce request is finalized.
  event ValidatorRenounceFinalized(address indexed consensusAddr, uint256 amount);
  /// @dev Emitted when the pool admin staked for themself.
  event Staked(address indexed validator, uint256 amount);
  /// @dev Emitted when the pool admin unstaked the amount of RON from themself.
  event Unstaked(address indexed validator, uint256 amount);
  /// @dev Emitted when the delegator staked for a validator.
  event Delegated(address indexed delegator, address indexed validator, uint256 amount);
  /// @dev Emitted when the delegator unstaked from a validator.
  event Undelegated(address indexed delegator, address indexed validator, uint256 amount);
  /// @dev Emitted when the minimum balance for being a validator is updated.
  event MinValidatorBalanceUpdated(uint256 threshold);

  ///////////////////////////////////////////////////////////////////////////////////////
  //                             FUNCTIONS FOR GOVERNANCE                              //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Returns the minimum threshold for being a validator candidate.
   */
  function minValidatorBalance() external view returns (uint256);

  /**
   * @dev Sets the minimum threshold for being a validator candidate.
   *
   * Requirements:
   * - The method caller is governance admin.
   *
   * Emits the `MinValidatorBalanceUpdated` event.
   *
   */
  function setMinValidatorBalance(uint256) external;

  ///////////////////////////////////////////////////////////////////////////////////////
  //                         FUNCTIONS FOR VALIDATOR CONTRACT                           //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Records the amount of reward `_reward` for the pending pool `_poolAddr`.
   *
   * Requirements:
   * - The method caller is validator contract.
   *
   * Emits the `PendingPoolUpdated` event.
   *
   * Note: This method should not be called after the pending pool is sinked.
   *
   */
  function recordReward(address _consensusAddr, uint256 _reward) external payable;

  /**
   * @dev Settles the pending pool and allocates rewards for the pool `_consensusAddr`.
   *
   * Requirements:
   * - The method caller is validator contract.
   *
   * Emits the `SettledPoolsUpdated` event.
   *
   */
  function settleRewardPools(address[] calldata _consensusAddrs) external;

  /**
   * @dev Handles when the pending reward pool of the validator is sinked.
   *
   * Requirements:
   * - The method caller is validator contract.
   *
   * Emits the `PendingPoolUpdated` event.
   *
   */
  function sinkPendingReward(address _consensusAddr) external;

  /**
   * @dev Deducts from staking amount of the validator `_consensusAddr` for `_amount`.
   *
   * Requirements:
   * - The method caller is validator contract.
   *
   * Emits the event `Unstaked` and `Undelegated` event.
   *
   */
  function deductStakingAmount(address _consensusAddr, uint256 _amount) external;

  ///////////////////////////////////////////////////////////////////////////////////////
  //                          FUNCTIONS FOR VALIDATOR CANDIDATE                        //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Proposes a candidate to become a valdiator.
   *
   * Requirements:
   * - The validator length is not exceeded the total validator threshold `maxValidatorCandidate()`.
   * - The amount is larger than or equal to the minimum validator balance `minValidatorBalance()`.
   *
   * Emits the `Staked` event and the `Delegated` event.
   *
   */
  function proposeValidator(
    address _consensusAddr,
    address payable _treasuryAddr,
    uint256 _commissionRate
  ) external payable;

  /**
   * @dev Self-delegates to the validator candidate `_consensusAddr`.
   *
   * Requirements:
   * - The consensus address is a validator candidate.
   * - The method caller is the pool admin.
   * - The `msg.value` is larger than 0.
   *
   * Emits the `Staked` event and the `Delegated` event.
   *
   */
  function stake(address _consensusAddr) external payable;

  /**
   * @dev Unstakes from the validator candidate `_consensusAddr` for `_amount`.
   *
   * Requirements:
   * - The consensus address is a validator candidate.
   * - The method caller is the pool admin.
   *
   * Emits the `Unstaked` event and the `Undelegated` event.
   *
   */
  function unstake(address _consensusAddr, uint256 _amount) external;

  /**
   * @dev Renounces being a validator candidate and takes back the delegated/staked amount.
   *
   * Requirements:
   * - The consensus address is a validator candidate.
   * - The method caller is the pool admin.
   *
   */
  function renounce(address consensusAddr) external;

  ///////////////////////////////////////////////////////////////////////////////////////
  //                             FUNCTIONS FOR DELEGATOR                               //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Stakes for a validator candidate `_consensusAddr`.
   *
   * Requirements:
   * - The consensus address is a validator candidate.
   * - The method caller is not the pool admin.
   *
   * Emits the `Delegated` event.
   *
   */
  function delegate(address _consensusAddr) external payable;

  /**
   * @dev Unstakes from a validator candidate `_consensusAddr` for `_amount`.
   *
   * Requirements:
   * - The method caller is not the pool admin.
   *
   * Emits the `Undelegated` event.
   *
   */
  function undelegate(address _consensusAddr, uint256 _amount) external;

  /**
   * @dev Unstakes an amount of RON from the `_consensusAddrSrc` and stake for `_consensusAddrDst`.
   *
   * Requirements:
   * - The method caller is not the pool admin.
   * - The consensus address `_consensusAddrDst` is a validator candidate.
   *
   * Emits the `Undelegated` event and the `Delegated` event.
   *
   */
  function redelegate(
    address _consensusAddrSrc,
    address _consensusAddrDst,
    uint256 _amount
  ) external;

  /**
   * @dev Returns the pending reward and the claimable reward of the user `_user`.
   */
  function getRewards(address _user, address[] calldata _poolAddrList)
    external
    view
    returns (uint256[] memory _pendings, uint256[] memory _claimables);

  /**
   * @dev Claims the reward of method caller.
   *
   * Emits the `RewardClaimed` event.
   *
   */
  function claimRewards(address[] calldata _consensusAddrList) external returns (uint256 _amount);

  /**
   * @dev Claims the rewards and delegates them to the consensus address.
   *
   * Requirements:
   * - The method caller is not the pool admin.
   * - The consensus address `_consensusAddrDst` is a validator candidate.
   *
   * Emits the `RewardClaimed` event and the `Delegated` event.
   *
   */
  function delegateRewards(address[] calldata _consensusAddrList, address _consensusAddrDst)
    external
    returns (uint256 _amount);
}
