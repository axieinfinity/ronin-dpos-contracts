// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IRewardPool.sol";

interface IStaking is IRewardPool {
  enum ValidatorState {
    ACTIVE,
    ON_REQUESTING_RENOUNCE,
    ON_CONFIRMED_RENOUNCE,
    RENOUNCED
  }

  struct ValidatorCandidate {
    /// @dev The candidate admin that stakes for the validator.
    address candidateAdmin;
    /// @dev Address of the validator that produces block, e.g. block.coinbase. This is so-called validator address.
    address consensusAddr;
    /// @dev Address that receives mining reward of the validator
    address payable treasuryAddr;
    /// @dev The percentile of reward that validators can be received, the rest goes to the delegators.
    /// Values in range [0; 100_00] stands for 0-100%
    uint256 commissionRate;
    /// @dev The RON amount from the validator.
    uint256 stakedAmount;
    /// @dev The RON amount from the delegator.
    uint256 delegatedAmount;
    /// @dev Mark the validator is a governance node
    bool governing;
    /// @dev State of the validator
    ValidatorState state;
    /// @dev Extra data
    bytes extraData;
  }

  /// @dev Emitted when the validator candidate is proposed.
  event ValidatorProposed(address indexed consensusAddr, address indexed candidateAdmin, uint256 indexed candidateIdx);
  /// @dev Emitted when the candidate admin staked for themself.
  event Staked(address indexed validator, uint256 amount);
  /// @dev Emitted when the candidate admin unstaked the amount of RON from themself.
  event Unstaked(address indexed validator, uint256 amount);
  /// @dev Emitted when the validator candidate requested to renounce.
  event ValidatorRenounceRequested(address indexed consensusAddr, uint256 amount);
  /// @dev Emitted when the renounce request is finalized.
  event ValidatorRenounceFinalized(address indexed consensusAddr, uint256 amount);
  /// @dev Emitted when the delegator staked for a validator.
  event Delegated(address indexed delegator, address indexed validator, uint256 amount);
  /// @dev Emitted when the delegator unstaked from a validator.
  event Undelegated(address indexed delegator, address indexed validator, uint256 amount);
  /// @dev Emitted when the address of validator contract is updated.
  event ValidatorContractUpdated(address);
  /// @dev Emitted when the address of governance admin is updated.
  event GovernanceAdminUpdated(address);
  /// @dev Emitted when the minimum balance for being a validator is updated.
  event MinValidatorBalanceUpdated(uint256 threshold);
  /// @dev Emitted when the maximum number of validator candidates is updated.
  event MaxValidatorCandidateUpdated(uint256 threshold);

  ///////////////////////////////////////////////////////////////////////////////////////
  //                             FUNCTIONS FOR GOVERNANCE                              //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Returns the governance admin address.
   */
  function governanceAdmin() external view returns (address);

  /**
   * @dev Returns validator contract
   */
  function validatorContract() external view returns (address);

  /**
   * @dev Returns the minimum threshold for being a validator candidate.
   */
  function minValidatorBalance() external view returns (uint256);

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
   * @dev Sets the minimum threshold for being a validator candidate.
   *
   * Requirements:
   * - The method caller is governance admin.
   *
   * Emits the `MinValidatorBalanceUpdated` event.
   *
   */
  function setMinValidatorBalance(uint256) external;

  /**
   * @dev Returns the maximum number of validator candidate.
   */
  function maxValidatorCandidate() external view returns (uint256);

  /**
   * @dev Sets the maximum number of validator candidate.
   *
   * Requirements:
   * - The method caller is governance admin.
   *
   * Emits the `MaxValidatorCandidateUpdated` event.
   *
   */
  function setMaxValidatorCandidate(uint256) external;

  ///////////////////////////////////////////////////////////////////////////////////////
  //                         FUNCTIONS FOR VALIDATOR CONTRACT                           //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Returns the validator candidate list.
   */
  function getValidatorCandidates() external view returns (ValidatorCandidate[] memory candidates);

  /**
   * @dev Returns the current candidate length.
   */
  function getValidatorCandidateLength() external view returns (uint256);

  /**
   * @dev Returns the validator candidate weights.
   */
  function getCandidateWeights() external view returns (address[] memory _candidates, uint256[] memory _weights);

  /**
   * @dev Records the amount of reward `_reward` for the pending pool `_poolAddr`.
   *
   * Requirements:
   * - The method caller is validator contract.
   *
   * Emits the `PendingPoolUpdated` event.
   *
   * @notice This method should not be called after the pending pool is sinked.
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

  /**
   * @dev Returns the commission rate of the validator candidate `_consensusAddr`.
   *
   * Values in [0; 100_00] stands for 0-100%.
   *
   * Requirements:
   * - The validator candidate is already existed.
   *
   */
  function commissionRateOf(address _consensusAddr) external view returns (uint256 _rate);

  /**
   * @dev Returns the treasury address of the validator candidate `_consensusAddr`.
   *
   * Requirements:
   * - The validator candidate is already existed.
   *
   */
  function treasuryAddressOf(address _consensusAddr) external view returns (address);

  ///////////////////////////////////////////////////////////////////////////////////////
  //                          FUNCTIONS FOR VALIDATOR CANDIDATE                        //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Proposes a candidate to become a valdiator.
   *
   * Requirements:
   * - The validator length is not exceeded the total validator threshold `maxValidatorCandidate`.
   * - The amount is larger than or equal to the minimum validator balance `minValidatorBalance()`.
   *
   * Emits the `ValidatorProposed` event.
   *
   * @return _candidateIdx The index of the candidate in the validator candidate list.
   *
   */
  function proposeValidator(
    address _consensusAddr,
    address payable _treasuryAddr,
    uint256 _commissionRate
  ) external payable returns (uint256 _candidateIdx);

  /**
   * @dev Self-delegates to the validator candidate `_consensusAddr`.
   *
   * Requirements:
   * - The candidate `_consensusAddr` is already existent.
   * - The method caller is the candidate admin.
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
   * - The candidate `_consensusAddr` is already existent.
   * - The method caller is the candidate admin.
   *
   * Emits the `Unstaked` event and the `Undelegated` event.
   *
   */
  function unstake(address _consensusAddr, uint256 _amount) external;

  /**
   * @dev Renounces being a validator candidate and takes back the delegated/staked amount.
   *
   * Requirements:
   * - The candidate `_consensusAddr` is already existent.
   * - The method caller is the candidate admin.
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
   * - The method caller is not the candidate admin.
   *
   * Emits the `Delegated` event.
   *
   */
  function delegate(address _consensusAddr) external payable;

  /**
   * @dev Unstakes from a validator candidate `_consensusAddr` for `_amount`.
   *
   * Requirements:
   * - The method caller is not the candidate admin.
   *
   * Emits the `Undelegated` event.
   *
   */
  function undelegate(address _consensusAddr, uint256 _amount) external;

  /**
   * @dev Unstakes an amount of RON from the `_consensusAddrSrc` and stake for `_consensusAddrDst`.
   *
   * Requirements:
   * - The method caller is not the candidate admin.
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
   * - The method caller is not the candidate admin.
   *
   * Emits the `RewardClaimed` event and the `Delegated` event.
   *
   */
  function delegateRewards(address[] calldata _consensusAddrList, address _consensusAddrDst)
    external
    returns (uint256 _amount);
}
