// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../libraries/AddressArrayUtils.sol";
import "../../interfaces/staking/ICandidateStaking.sol";
import "./BaseStaking.sol";

abstract contract CandidateStaking is BaseStaking, ICandidateStaking {
  /// @dev The minimum threshold for being a validator candidate.
  uint256 internal _minValidatorStakingAmount;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private ______gap;

  /**
   * @inheritdoc ICandidateStaking
   */
  function minValidatorStakingAmount() public view override returns (uint256) {
    return _minValidatorStakingAmount;
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
  function applyValidatorCandidate(
    address _candidateAdmin,
    address _consensusAddr,
    address payable _treasuryAddr,
    address _bridgeOperatorAddr,
    uint256 _commissionRate
  ) external payable override nonReentrant {
    if (isAdminOfActivePool(msg.sender)) revert ErrAdminOfAnyActivePoolForbidden(msg.sender);

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
    _validatorContract.execRequestUpdateCommissionRate(_consensusAddr, _effectiveDaysOnwards, _commissionRate);
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function deprecatePools(address[] calldata _pools) external override onlyValidatorContract {
    if (_pools.length == 0) {
      return;
    }

    uint256 _amount;
    for (uint _i = 0; _i < _pools.length; _i++) {
      PoolDetail storage _pool = _stakingPool[_pools[_i]];
      // Deactivate the pool admin in the active mapping.
      delete _adminOfActivePoolMapping[_pool.admin];

      // Deduct and transfer the self staking amount to the pool admin.
      _amount = _pool.stakingAmount;
      if (_amount > 0) {
        _deductStakingAmount(_pool, _amount);
        if (!_unsafeSendRON(payable(_pool.admin), _amount, 3500)) {
          emit StakingAmountTransferFailed(_pool.addr, _pool.admin, _amount, address(this).balance);
        }
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
  function unstake(address _consensusAddr, uint256 _amount)
    external
    override
    nonReentrant
    poolIsActive(_consensusAddr)
  {
    if (_amount == 0) revert ErrUnstakeZeroAmount();
    address _requester = msg.sender;
    PoolDetail storage _pool = _stakingPool[_consensusAddr];
    uint256 _remainAmount = _pool.stakingAmount - _amount;
    if (_remainAmount < _minValidatorStakingAmount) revert ErrStakingAmountLeft();

    _unstake(_pool, _requester, _amount);
    if (_unsafeSendRON(payable(_requester), _amount, 3500)) revert ErrCannotTransferRON();
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function requestRenounce(address _consensusAddr)
    external
    override
    poolIsActive(_consensusAddr)
    onlyPoolAdmin(_stakingPool[_consensusAddr], msg.sender)
  {
    _validatorContract.requestRevokeCandidate(_consensusAddr, _waitingSecsToRevoke);
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function requestEmergencyExit(address _consensusAddr)
    external
    override
    poolIsActive(_consensusAddr)
    onlyPoolAdmin(_stakingPool[_consensusAddr], msg.sender)
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
    if (AddressArrayUtils.hasDuplicate(_diffAddrs)) revert ErrThreeOperationAddrNotDistinct();

    _validatorContract.grantValidatorCandidate(
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
}
