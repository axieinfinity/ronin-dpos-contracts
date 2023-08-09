// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/consumers/GlobalConfigConsumer.sol";
import "../../extensions/consumers/PercentageConsumer.sol";
import "../../libraries/AddressArrayUtils.sol";
import "../../interfaces/staking/ICandidateStaking.sol";
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
  function setMinValidatorStakingAmount(uint256 _threshold) external override onlyAdmin {
    _setMinValidatorStakingAmount(_threshold);
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function setCommissionRateRange(uint256 _minRate, uint256 _maxRate) external override onlyAdmin {
    _setCommissionRateRange(_minRate, _maxRate);
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function applyValidatorCandidate(
    address _candidateAdmin,
    address _consensusAddr,
    address payable _treasuryAddr,
    uint256 _commissionRate
  ) external payable override nonReentrant {
    if (isAdminOfActivePool(msg.sender)) revert ErrAdminOfAnyActivePoolForbidden(msg.sender);
    if (_commissionRate > _maxCommissionRate || _commissionRate < _minCommissionRate) revert ErrInvalidCommissionRate();

    uint256 _amount = msg.value;
    address payable _poolAdmin = payable(msg.sender);
    _applyValidatorCandidate({
      _poolAdmin: _poolAdmin,
      _candidateAdmin: _candidateAdmin,
      _consensusAddr: _consensusAddr,
      _treasuryAddr: _treasuryAddr,
      _commissionRate: _commissionRate,
      _amount: _amount
    });

    PoolDetail storage _pool = _stakingPool[_consensusAddr];
    _pool.admin = _poolAdmin;
    _pool.addr = _consensusAddr;
    _adminOfActivePoolMapping[_poolAdmin] = _consensusAddr;

    _stake(_stakingPool[_consensusAddr], _poolAdmin, _amount);
    emit PoolApproved(_consensusAddr, _poolAdmin);
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function requestUpdateCommissionRate(
    address _consensusAddr,
    uint256 _effectiveDaysOnwards,
    uint256 _commissionRate
  ) external override poolIsActive(_consensusAddr) onlyPoolAdmin(_stakingPool[_consensusAddr], msg.sender) {
    if (_commissionRate > _maxCommissionRate || _commissionRate < _minCommissionRate) revert ErrInvalidCommissionRate();
    IRoninValidatorSet(getContract(ContractType.VALIDATOR)).execRequestUpdateCommissionRate(
      _consensusAddr,
      _effectiveDaysOnwards,
      _commissionRate
    );
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function execDeprecatePools(
    address[] calldata _pools,
    uint256 _newPeriod
  ) external override onlyContract(ContractType.VALIDATOR) {
    if (_pools.length == 0) {
      return;
    }

    for (uint _i = 0; _i < _pools.length; ) {
      PoolDetail storage _pool = _stakingPool[_pools[_i]];
      // Deactivate the pool admin in the active mapping.
      delete _adminOfActivePoolMapping[_pool.admin];

      // Deduct and transfer the self staking amount to the pool admin.
      uint256 _deductingAmount = _pool.stakingAmount;
      if (_deductingAmount > 0) {
        _deductStakingAmount(_pool, _deductingAmount);
        if (!_unsafeSendRONLimitGas(payable(_pool.admin), _deductingAmount, DEFAULT_ADDITION_GAS)) {
          emit StakingAmountTransferFailed(_pool.addr, _pool.admin, _deductingAmount, address(this).balance);
        }
      }

      // Settle the unclaimed reward and transfer to the pool admin.
      uint256 _lastRewardAmount = _claimReward(_pools[_i], _pool.admin, _newPeriod);
      if (_lastRewardAmount > 0) {
        _unsafeSendRONLimitGas(payable(_pool.admin), _lastRewardAmount, DEFAULT_ADDITION_GAS);
      }

      unchecked {
        ++_i;
      }
    }

    emit PoolsDeprecated(_pools);
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function stake(address _consensusAddr) external payable override noEmptyValue poolIsActive(_consensusAddr) {
    _stake(_stakingPool[_consensusAddr], msg.sender, msg.value);
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function unstake(
    address _consensusAddr,
    uint256 _amount
  ) external override nonReentrant poolIsActive(_consensusAddr) {
    if (_amount == 0) revert ErrUnstakeZeroAmount();
    address _requester = msg.sender;
    PoolDetail storage _pool = _stakingPool[_consensusAddr];
    uint256 _remainAmount = _pool.stakingAmount - _amount;
    if (_remainAmount < _minValidatorStakingAmount) revert ErrStakingAmountLeft();

    _unstake(_pool, _requester, _amount);
    if (!_unsafeSendRONLimitGas(payable(_requester), _amount, DEFAULT_ADDITION_GAS)) revert ErrCannotTransferRON();
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function requestRenounce(
    address _consensusAddr
  ) external override poolIsActive(_consensusAddr) onlyPoolAdmin(_stakingPool[_consensusAddr], msg.sender) {
    IRoninValidatorSet(getContract(ContractType.VALIDATOR)).execRequestRenounceCandidate(
      _consensusAddr,
      _waitingSecsToRevoke
    );
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function requestEmergencyExit(
    address _consensusAddr
  ) external override poolIsActive(_consensusAddr) onlyPoolAdmin(_stakingPool[_consensusAddr], msg.sender) {
    IRoninValidatorSet(getContract(ContractType.VALIDATOR)).execEmergencyExit(_consensusAddr, _waitingSecsToRevoke);
  }

  /**
   * @dev See `ICandidateStaking-applyValidatorCandidate`
   */
  function _applyValidatorCandidate(
    address payable _poolAdmin,
    address _candidateAdmin,
    address _consensusAddr,
    address payable _treasuryAddr,
    uint256 _commissionRate,
    uint256 _amount
  ) internal {
    if (!_unsafeSendRONLimitGas(_poolAdmin, 0, DEFAULT_ADDITION_GAS))
      revert ErrCannotInitTransferRON(_poolAdmin, "pool admin");
    if (!_unsafeSendRONLimitGas(_treasuryAddr, 0, DEFAULT_ADDITION_GAS))
      revert ErrCannotInitTransferRON(_treasuryAddr, "treasury");
    if (_amount < _minValidatorStakingAmount) revert ErrInsufficientStakingAmount();
    if (_poolAdmin != _candidateAdmin || _candidateAdmin != _treasuryAddr) revert ErrThreeInteractionAddrsNotEqual();

    {
      address[] memory _diffAddrs = new address[](2);
      _diffAddrs[0] = _poolAdmin;
      _diffAddrs[1] = _consensusAddr;
      if (AddressArrayUtils.hasDuplicate(_diffAddrs)) revert AddressArrayUtils.ErrDuplicated(msg.sig);
    }

    IRoninValidatorSet(getContract(ContractType.VALIDATOR)).execApplyValidatorCandidate(
      _candidateAdmin,
      _consensusAddr,
      _treasuryAddr,
      _commissionRate
    );
  }

  /**
   * @dev See `ICandidateStaking-stake`
   */
  function _stake(
    PoolDetail storage _pool,
    address _requester,
    uint256 _amount
  ) internal onlyPoolAdmin(_pool, _requester) {
    _pool.stakingAmount += _amount;
    _changeDelegatingAmount(_pool, _requester, _pool.stakingAmount, _pool.stakingTotal + _amount);
    _pool.lastDelegatingTimestamp[_requester] = block.timestamp;
    emit Staked(_pool.addr, _amount);
  }

  /**
   * @dev See `ICandidateStaking-unstake`
   */
  function _unstake(
    PoolDetail storage _pool,
    address _requester,
    uint256 _amount
  ) internal onlyPoolAdmin(_pool, _requester) {
    if (_amount > _pool.stakingAmount) revert ErrInsufficientStakingAmount();
    if (_pool.lastDelegatingTimestamp[_requester] + _cooldownSecsToUndelegate > block.timestamp) {
      revert ErrUnstakeTooEarly();
    }

    _pool.stakingAmount -= _amount;
    _changeDelegatingAmount(_pool, _requester, _pool.stakingAmount, _pool.stakingTotal - _amount);
    emit Unstaked(_pool.addr, _amount);
  }

  /**
   * @dev Deducts from staking amount of the validator `_consensusAddr` for `_amount`.
   *
   * Emits the event `Unstaked`.
   *
   * @return The actual deducted amount
   */
  function _deductStakingAmount(PoolDetail storage _pool, uint256 _amount) internal virtual returns (uint256);

  /**
   * @dev Sets the minimum threshold for being a validator candidate.
   *
   * Emits the `MinValidatorStakingAmountUpdated` event.
   *
   */
  function _setMinValidatorStakingAmount(uint256 _threshold) internal {
    _minValidatorStakingAmount = _threshold;
    emit MinValidatorStakingAmountUpdated(_threshold);
  }

  /**
   * @dev Sets the max commission rate that a candidate can set.
   *
   * Emits the `MaxCommissionRateUpdated` event.
   *
   */
  function _setCommissionRateRange(uint256 _minRate, uint256 _maxRate) internal {
    if (_maxRate > _MAX_PERCENTAGE || _minRate > _maxRate) revert ErrInvalidCommissionRate();
    _maxCommissionRate = _maxRate;
    _minCommissionRate = _minRate;
    emit CommissionRateRangeUpdated(_minRate, _maxRate);
  }
}
