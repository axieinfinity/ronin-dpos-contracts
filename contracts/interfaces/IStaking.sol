// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IRewardPool.sol";

interface IStaking is IRewardPool {
  struct PoolDetail {
    // Address of the pool
    address addr;
    // Pool admin address
    address admin;
    // Self-staking amount
    uint256 stakingAmount;
    // Total number of RON staking for the pool
    uint256 stakingTotal;
    // Mapping from delegator => delegating amount
    mapping(address => uint256) delegatingAmount;
    // Mapping from delegator => the last period that delegator staked
    mapping(address => uint256) lastDelegatingPeriod;
  }

  /// @dev Emitted when the validator pool is approved.
  event PoolApproved(address indexed validator, address indexed admin);
  /// @dev Emitted when the validator pool is deprecated.
  event PoolsDeprecated(address[] validator);
  /// @dev Emitted when the staking amount transfer failed.
  event StakingAmountTransferFailed(
    address indexed validator,
    address indexed admin,
    uint256 amount,
    uint256 contractBalance
  );
  /// @dev Emitted when the pool admin staked for themself.
  event Staked(address indexed consensuAddr, uint256 amount);
  /// @dev Emitted when the pool admin unstaked the amount of RON from themself.
  event Unstaked(address indexed consensuAddr, uint256 amount);
  /// @dev Emitted when the delegator staked for a validator candidate.
  event Delegated(address indexed delegator, address indexed consensuAddr, uint256 amount);
  /// @dev Emitted when the delegator unstaked from a validator candidate.
  event Undelegated(address indexed delegator, address indexed consensuAddr, uint256 amount);
  /// @dev Emitted when the minimum staking amount for being a validator is updated.
  event MinValidatorStakingAmountUpdated(uint256 threshold);

  ///////////////////////////////////////////////////////////////////////////////////////
  //                             FUNCTIONS FOR GOVERNANCE                              //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Returns the minimum threshold for being a validator candidate.
   */
  function minValidatorStakingAmount() external view returns (uint256);

  /**
   * @dev Sets the minimum threshold for being a validator candidate.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the `MinValidatorStakingAmountUpdated` event.
   *
   */
  function setMinValidatorStakingAmount(uint256) external;

  ///////////////////////////////////////////////////////////////////////////////////////
  //                         FUNCTIONS FOR VALIDATOR CONTRACT                           //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Records the amount of rewards `_rewards` for the pools `_poolAddrs`.
   *
   * Requirements:
   * - The method caller is validator contract.
   *
   * Emits the event `PoolsUpdated` once the contract recorded the rewards successfully.
   * Emits the event `PoolsUpdateFailed` once the input array lengths are not equal.
   * Emits the event `PoolUpdateConflicted` when the pool is already updated in the period.
   *
   * Note: This method should be called once at the period ending.
   *
   */
  function recordRewards(
    uint256 _period,
    address[] calldata _consensusAddrs,
    uint256[] calldata _rewards
  ) external payable;

  /**
   * @dev Deducts from staking amount of the validator `_consensusAddr` for `_amount`.
   *
   * Requirements:
   * - The method caller is validator contract.
   *
   * Emits the event `Unstaked`.
   *
   */
  function deductStakingAmount(address _consensusAddr, uint256 _amount) external;

  /**
   * @dev Deprecates the pool.
   *
   * Requirements:
   * - The method caller is validator contract.
   *
   * Emits the event `PoolsDeprecated` and `Unstaked` events.
   * Emits the event `StakingAmountTransferFailed` if the contract cannot transfer RON back to the pool admin.
   *
   */
  function deprecatePools(address[] calldata _pools) external;

  ///////////////////////////////////////////////////////////////////////////////////////
  //                          FUNCTIONS FOR VALIDATOR CANDIDATE                        //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Proposes a candidate to become a validator.
   *
   * Requirements:
   * - The method caller is able to receive RON.
   * - The treasury is able to receive RON.
   * - The amount is larger than or equal to the minimum validator staking amount `minValidatorStakingAmount()`.
   *
   * Emits the event `PoolApproved`.
   *
   * @param _candidateAdmin the candidate admin will be stored in the validator contract, used for calling function that affects
   * to its candidate. IE: scheduling maintenance.
   *
   */
  function applyValidatorCandidate(
    address _candidateAdmin,
    address _consensusAddr,
    address payable _treasuryAddr,
    address _bridgeOperatorAddr,
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
   * Emits the event `Staked`.
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
   * Emits the event `Unstaked`.
   *
   */
  function unstake(address _consensusAddr, uint256 _amount) external;

  /**
   * @dev Renounces being a validator candidate and takes back the delegating/staking amount.
   *
   * Requirements:
   * - The consensus address is a validator candidate.
   * - The method caller is the pool admin.
   *
   */
  function requestRenounce(address _consensusAddr) external;

  ///////////////////////////////////////////////////////////////////////////////////////
  //                             FUNCTIONS FOR DELEGATOR                               //
  ///////////////////////////////////////////////////////////////////////////////////////

  function setRevokePeriod(uint256 _periods) external;
  function setMinPeriodsToUndelegate(uint256 _minPeriods) external;

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
   * @dev Bulk unstakes from a list of candidates.
   *
   * Requirements:
   * - The method caller is not the pool admin.
   *
   * Emits the events `Undelegated`.
   *
   */
  function bulkUndelegate(address[] calldata _consensusAddrs, uint256[] calldata _amounts) external;

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
   * @dev Returns the claimable reward of the user `_user`.
   */
  function getRewards(address _user, address[] calldata _poolAddrList)
    external
    view
    returns (uint256[] memory _rewards);

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

  /**
   * @dev Returns the staking pool detail.
   */
  function getStakingPool(address)
    external
    view
    returns (
      address _admin,
      uint256 _stakingAmount,
      uint256 _stakingTotal
    );
}
