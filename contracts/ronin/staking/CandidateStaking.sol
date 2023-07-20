// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/consumers/GlobalConfigConsumer.sol";
import "../../extensions/consumers/PercentageConsumer.sol";
import "../../libraries/AddressArrayUtils.sol";
import "../../interfaces/staking/ICandidateStaking.sol";
import "../../interfaces/IProfile.sol";
import "./BaseStaking.sol";

abstract contract CandidateStaking is BaseStaking, ICandidateStaking, GlobalConfigConsumer, PercentageConsumer {
  /// @dev The minimum threshold for being a validator candidate.
  uint256 internal _minValidatorStakingAmount;

  /// @dev The max commission rate that the validator can set (in range of [0;100_00] means [0-100%])
  uint256 internal _maxCommissionRate;
  /// @dev The min commission rate that the validator can set (in range of [0;100_00] means [0-100%])
  uint256 internal _minCommissionRate;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[48] ______gap;

  /**
   * @inheritdoc ICandidateStaking
   */
  function minValidatorStakingAmount() public view override returns (uint256) {
    return _minValidatorStakingAmount;
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function getCommissionRateRange() external view override returns (uint256, uint256) {
    return (_minCommissionRate, _maxCommissionRate);
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function setMinValidatorStakingAmount(uint256 threshold) external override onlyAdmin {
    _setMinValidatorStakingAmount(threshold);
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function setCommissionRateRange(uint256 minRate, uint256 maxRate) external override onlyAdmin {
    _setCommissionRateRange(minRate, maxRate);
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function applyValidatorCandidate(
    address candidateAdmin,
    TConsensus consensusAddr,
    address payable treasuryAddr,
    uint256 commissionRate
  ) external payable override nonReentrant {
    if (isAdminOfActivePool(msg.sender)) revert ErrAdminOfAnyActivePoolForbidden(msg.sender);
    if (commissionRate > _maxCommissionRate || commissionRate < _minCommissionRate) revert ErrInvalidCommissionRate();

    uint256 amount = msg.value;
    address payable poolAdmin = payable(msg.sender);
    address poolId = TConsensus.unwrap(consensusAddr);

    _applyValidatorCandidate({
      poolAdmin: poolAdmin,
      candidateAdmin: candidateAdmin,
      poolId: poolId,
      treasuryAddr: treasuryAddr,
      commissionRate: commissionRate,
      amount: amount
    });

    PoolDetail storage _pool = _poolDetail[poolId];
    _pool.admin = poolAdmin;
    _pool.id = poolId;
    _adminOfActivePoolMapping[poolAdmin] = poolId;

    _stake(_poolDetail[poolId], poolAdmin, amount);
    emit PoolApproved(poolId, poolAdmin);
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function requestUpdateCommissionRate(
    TConsensus consensusAddr,
    uint256 effectiveDaysOnwards,
    uint256 commissionRate
  )
    external
    override
    poolOfConsensusIsActive(consensusAddr)
    onlyPoolAdmin(_poolDetail[_convertC2P(consensusAddr)], msg.sender)
  {
    if (commissionRate > _maxCommissionRate || commissionRate < _minCommissionRate) revert ErrInvalidCommissionRate();
    IRoninValidatorSet(getContract(ContractType.VALIDATOR)).execRequestUpdateCommissionRate(
      _convertC2P(consensusAddr),
      effectiveDaysOnwards,
      commissionRate
    );
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function execDeprecatePools(
    address[] calldata poolIds,
    uint256 newPeriod
  ) external override onlyContract(ContractType.VALIDATOR) {
    if (poolIds.length == 0) {
      return;
    }

    for (uint i = 0; i < poolIds.length; ) {
      address poolId = poolIds[i];
      PoolDetail storage _pool = _poolDetail[poolId];
      // Deactivate the pool admin in the active mapping.
      delete _adminOfActivePoolMapping[_pool.admin];

      // Deduct and transfer the self staking amount to the pool admin.
      uint256 deductingAmount = _pool.stakingAmount;
      if (deductingAmount > 0) {
        _deductStakingAmount(_pool, deductingAmount);
        if (!_unsafeSendRON(payable(_pool.admin), deductingAmount, DEFAULT_ADDITION_GAS)) {
          emit StakingAmountTransferFailed(_pool.id, _pool.admin, deductingAmount, address(this).balance);
        }
      }

      // Settle the unclaimed reward and transfer to the pool admin.
      uint256 lastRewardAmount = _claimReward(poolId, _pool.admin, newPeriod);
      if (lastRewardAmount > 0) {
        _unsafeSendRON(payable(_pool.admin), lastRewardAmount, DEFAULT_ADDITION_GAS);
      }

      unchecked {
        ++i;
      }
    }

    emit PoolsDeprecated(poolIds);
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function stake(
    TConsensus consensusAddr
  ) external payable override noEmptyValue poolOfConsensusIsActive(consensusAddr) {
    address poolId = _convertC2P(consensusAddr);
    _stake(_poolDetail[poolId], msg.sender, msg.value);
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function unstake(
    TConsensus consensusAddr,
    uint256 amount
  ) external override nonReentrant poolOfConsensusIsActive(consensusAddr) {
    if (amount == 0) revert ErrUnstakeZeroAmount();
    address requester = msg.sender;
    address poolId = _convertC2P(consensusAddr);
    PoolDetail storage _pool = _poolDetail[poolId];
    uint256 remainAmount = _pool.stakingAmount - amount;
    if (remainAmount < _minValidatorStakingAmount) revert ErrStakingAmountLeft();

    _unstake(_pool, requester, amount);
    if (!_unsafeSendRON(payable(requester), amount, DEFAULT_ADDITION_GAS)) revert ErrCannotTransferRON();
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function requestRenounce(
    TConsensus consensusAddr
  )
    external
    override
    poolOfConsensusIsActive(consensusAddr)
    onlyPoolAdmin(_poolDetail[_convertC2P(consensusAddr)], msg.sender)
  {
    IRoninValidatorSet(getContract(ContractType.VALIDATOR)).execRequestRenounceCandidate(
      _convertC2P(consensusAddr),
      _waitingSecsToRevoke
    );
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function requestEmergencyExit(
    TConsensus consensusAddr
  )
    external
    override
    poolOfConsensusIsActive(consensusAddr)
    onlyPoolAdmin(_poolDetail[_convertC2P(consensusAddr)], msg.sender)
  {
    IRoninValidatorSet(getContract(ContractType.VALIDATOR)).execEmergencyExit(
      _convertC2P(consensusAddr),
      _waitingSecsToRevoke
    );
  }

  /**
   * @dev See `ICandidateStaking-applyValidatorCandidate`
   */
  function _applyValidatorCandidate(
    address payable poolAdmin,
    address candidateAdmin,
    address poolId,
    address payable treasuryAddr,
    uint256 commissionRate,
    uint256 amount
  ) internal {
    if (!_unsafeSendRON(poolAdmin, 0, DEFAULT_ADDITION_GAS)) revert ErrCannotInitTransferRON(poolAdmin, "pool admin");
    if (!_unsafeSendRON(treasuryAddr, 0, DEFAULT_ADDITION_GAS)) {
      revert ErrCannotInitTransferRON(treasuryAddr, "treasury");
    }
    if (amount < _minValidatorStakingAmount) revert ErrInsufficientStakingAmount();
    if (poolAdmin != candidateAdmin || candidateAdmin != treasuryAddr) revert ErrThreeInteractionAddrsNotEqual();

    {
      address[] memory diffAddrs = new address[](3);
      diffAddrs[0] = poolAdmin;
      diffAddrs[1] = poolId;
      if (AddressArrayUtils.hasDuplicate(diffAddrs)) revert AddressArrayUtils.ErrDuplicated(msg.sig);
    }

    IRoninValidatorSet(getContract(ContractType.VALIDATOR)).execApplyValidatorCandidate(
      candidateAdmin,
      poolId,
      treasuryAddr,
      commissionRate
    );

    IProfile profileContract = IProfile(getContract(ContractType.PROFILE));
    profileContract.execApplyValidatorCandidate(candidateAdmin, poolId, treasuryAddr);
  }

  /**
   * @dev See `ICandidateStaking-stake`
   */
  function _stake(
    PoolDetail storage _pool,
    address requester,
    uint256 amount
  ) internal onlyPoolAdmin(_pool, requester) {
    _pool.stakingAmount += amount;
    _changeDelegatingAmount(_pool, requester, _pool.stakingAmount, _pool.stakingTotal + amount);
    _pool.lastDelegatingTimestamp[requester] = block.timestamp;
    emit Staked(_pool.id, amount);
  }

  /**
   * @dev See `ICandidateStaking-unstake`
   */
  function _unstake(
    PoolDetail storage _pool,
    address requester,
    uint256 amount
  ) internal onlyPoolAdmin(_pool, requester) {
    if (amount > _pool.stakingAmount) revert ErrInsufficientStakingAmount();
    if (_pool.lastDelegatingTimestamp[requester] + _cooldownSecsToUndelegate > block.timestamp) {
      revert ErrUnstakeTooEarly();
    }

    _pool.stakingAmount -= amount;
    _changeDelegatingAmount(_pool, requester, _pool.stakingAmount, _pool.stakingTotal - amount);
    emit Unstaked(_pool.id, amount);
  }

  /**
   * @dev Deducts from staking amount of the validator `_consensusAddr` for `_amount`.
   *
   * Emits the event `Unstaked`.
   *
   * @return The actual deducted amount
   */
  function _deductStakingAmount(PoolDetail storage _pool, uint256 amount) internal virtual returns (uint256);

  /**
   * @dev Sets the minimum threshold for being a validator candidate.
   *
   * Emits the `MinValidatorStakingAmountUpdated` event.
   *
   */
  function _setMinValidatorStakingAmount(uint256 threshold) internal {
    _minValidatorStakingAmount = threshold;
    emit MinValidatorStakingAmountUpdated(threshold);
  }

  /**
   * @dev Sets the max commission rate that a candidate can set.
   *
   * Emits the `MaxCommissionRateUpdated` event.
   *
   */
  function _setCommissionRateRange(uint256 minRate, uint256 maxRate) internal {
    if (maxRate > _MAX_PERCENTAGE || minRate > maxRate) revert ErrInvalidCommissionRate();
    _maxCommissionRate = maxRate;
    _minCommissionRate = minRate;
    emit CommissionRateRangeUpdated(minRate, maxRate);
  }
}
