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
    address _bridgeOperatorAddr,
    uint256 _commissionRate
  ) external payable override nonReentrant {
    if (isAdminOfActivePool(msg.sender)) revert ErrAdminOfAnyActivePoolForbidden(msg.sender);
    if (_commissionRate > _maxCommissionRate || _commissionRate < _minCommissionRate) revert ErrInvalidCommissionRate();

    uint256 _amount = msg.value;
    address payable _poolAdmin = payable(msg.sender);
    _applyValidatorCandidate(
      _poolAdmin,
      _candidateAdmin,
      _consensusAddr,
      _treasuryAddr,
      _bridgeOperatorAddr,
      _commissionRate,
      _amount
    );

    poolOfConsensusMapping[_consensusAddr] = _consensusAddr;

    PoolDetail storage _pool = _getStakingPool(_consensusAddr);
    _pool.admin = _poolAdmin;
    _pool.addr = _consensusAddr;
    _adminOfActivePoolMapping[_poolAdmin] = _consensusAddr;

    _stake(_pool, _poolAdmin, _amount);
    emit PoolApproved(_consensusAddr, _poolAdmin);
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function requestUpdateCommissionRate(
    address _consensusAddr,
    uint256 _effectiveDaysOnwards,
    uint256 _commissionRate
  ) external override poolIsActive(_consensusAddr) onlyPoolAdmin(_getStakingPool(_consensusAddr), msg.sender) {
    if (_commissionRate > _maxCommissionRate || _commissionRate < _minCommissionRate) revert ErrInvalidCommissionRate();
    _validatorContract.execRequestUpdateCommissionRate(_consensusAddr, _effectiveDaysOnwards, _commissionRate);
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function execDeprecatePools(address[] calldata _consensusAddrs, uint256 _newPeriod)
    external
    override
    onlyValidatorContract
  {
    if (_consensusAddrs.length == 0) {
      return;
    }

    address[] memory _pools = new address[](_consensusAddrs.length);

    for (uint _i = 0; _i < _consensusAddrs.length; _i++) {
      _pools[_i] = poolOfConsensusMapping[_consensusAddrs[_i]];
      PoolDetail storage _pool = _getStakingPool(_pools[_i]);

      // Deactivate the pool admin in the active mapping.
      delete _adminOfActivePoolMapping[_pool.admin];

      // Deduct and transfer the self staking amount to the pool admin.
      uint256 _deductingAmount = _pool.stakingAmount;
      if (_deductingAmount > 0) {
        _deductStakingAmount(_pool, _deductingAmount);
        if (!_unsafeSendRON(payable(_pool.admin), _deductingAmount, DEFAULT_ADDITION_GAS)) {
          emit StakingAmountTransferFailed(_pool.addr, _pool.admin, _deductingAmount, address(this).balance);
        }
      }

      // Settle the unclaimed reward and transfer to the pool admin.
      uint256 _lastRewardAmount = _claimReward(_pools[_i], _pool.admin, _newPeriod);
      if (_lastRewardAmount > 0) {
        _unsafeSendRON(payable(_pool.admin), _lastRewardAmount, DEFAULT_ADDITION_GAS);
      }

      delete poolOfConsensusMapping[_consensusAddrs[_i]];
    }

    emit PoolsDeprecated(_pools);
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function stake(address _consensusAddr) external payable override noEmptyValue poolIsActive(_consensusAddr) {
    _stake(_getStakingPool(_consensusAddr), msg.sender, msg.value);
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function unstake(address _consensusAddr, uint256 _amount)
    external
    override
    nonReentrant
    poolIsActive(_consensusAddr)
  {
    if (_amount == 0) revert ErrUnstakeZeroAmount();
    address _requester = msg.sender;
    PoolDetail storage _pool = _getStakingPool(_consensusAddr);
    uint256 _remainAmount = _pool.stakingAmount - _amount;
    if (_remainAmount < _minValidatorStakingAmount) revert ErrStakingAmountLeft();

    _unstake(_pool, _requester, _amount);
    if (!_unsafeSendRON(payable(_requester), _amount, DEFAULT_ADDITION_GAS)) revert ErrCannotTransferRON();
  }

  function updateConsensusAddr(address _oldConsensusAddr, address _newConsensusAddr)
    external
    poolIsActive(_oldConsensusAddr)
    onlyPoolAdmin(_getStakingPool(_oldConsensusAddr), msg.sender)
  {
    if (_oldConsensusAddr == _newConsensusAddr) revert ErrInvalidInput();
    PoolDetail storage _pool = _getStakingPool(_oldConsensusAddr);

    _adminOfActivePoolMapping[_pool.admin] = _newConsensusAddr;
    poolOfConsensusMapping[_newConsensusAddr] = poolOfConsensusMapping[_oldConsensusAddr];
    delete poolOfConsensusMapping[_oldConsensusAddr];
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function requestRenounce(address _consensusAddr)
    external
    override
    poolIsActive(_consensusAddr)
    onlyPoolAdmin(_getStakingPool(_consensusAddr), msg.sender)
  {
    _validatorContract.execRequestRenounceCandidate(_consensusAddr, _waitingSecsToRevoke);
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function requestEmergencyExit(address _consensusAddr)
    external
    override
    poolIsActive(_consensusAddr)
    onlyPoolAdmin(_getStakingPool(_consensusAddr), msg.sender)
  {
    _validatorContract.execEmergencyExit(_consensusAddr, _waitingSecsToRevoke);
  }

  /**
   * @dev See `ICandidateStaking-applyValidatorCandidate`
   */
  function _applyValidatorCandidate(
    address payable _poolAdmin,
    address _candidateAdmin,
    address _consensusAddr,
    address payable _treasuryAddr,
    address _bridgeOperatorAddr,
    uint256 _commissionRate,
    uint256 _amount
  ) internal {
    if (!_unsafeSendRON(_poolAdmin, 0)) revert ErrCannotInitTransferRON(_poolAdmin, "pool admin");
    if (!_unsafeSendRON(_treasuryAddr, 0)) revert ErrCannotInitTransferRON(_treasuryAddr, "treasury");
    if (_amount < _minValidatorStakingAmount) revert ErrInsufficientStakingAmount();
    if (_poolAdmin != _candidateAdmin || _candidateAdmin != _treasuryAddr) revert ErrThreeInteractionAddrsNotEqual();

    address[] memory _diffAddrs = new address[](3);
    _diffAddrs[0] = _poolAdmin;
    _diffAddrs[1] = _consensusAddr;
    _diffAddrs[2] = _bridgeOperatorAddr;
    if (AddressArrayUtils.hasDuplicate(_diffAddrs)) revert ErrThreeOperationAddrsNotDistinct();

    _validatorContract.execApplyValidatorCandidate(
      _candidateAdmin,
      _consensusAddr,
      _treasuryAddr,
      _bridgeOperatorAddr,
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
