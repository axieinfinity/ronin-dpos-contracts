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
    require(!isActivePoolAdmin(msg.sender), "CandidateStaking: pool admin is active");

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
    _activePoolAdminMapping[_poolAdmin] = _consensusAddr;

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
  ) external override poolExists(_consensusAddr) onlyPoolAdmin(_stakingPool[_consensusAddr], msg.sender) {
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
      delete _activePoolAdminMapping[_pool.admin];

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
  function stake(address _consensusAddr) external payable override noEmptyValue poolExists(_consensusAddr) {
    _stake(_stakingPool[_consensusAddr], msg.sender, msg.value);
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function unstake(address _consensusAddr, uint256 _amount) external override nonReentrant poolExists(_consensusAddr) {
    require(_amount > 0, "CandidateStaking: invalid amount");
    address _delegator = msg.sender;
    PoolDetail storage _pool = _stakingPool[_consensusAddr];
    uint256 _remainAmount = _pool.stakingAmount - _amount;
    require(_remainAmount >= _minValidatorStakingAmount, "CandidateStaking: invalid staking amount left");

    _unstake(_pool, _delegator, _amount);
    require(_sendRON(payable(_delegator), _amount), "CandidateStaking: could not transfer RON");
  }

  /**
   * @inheritdoc ICandidateStaking
   */
  function requestRenounce(address _consensusAddr)
    external
    override
    poolExists(_consensusAddr)
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
    poolExists(_consensusAddr)
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
    require(_sendRON(_poolAdmin, 0), "CandidateStaking: pool admin cannot receive RON");
    require(_sendRON(_treasuryAddr, 0), "CandidateStaking: treasury cannot receive RON");
    require(_amount >= _minValidatorStakingAmount, "CandidateStaking: insufficient amount");

    require(
      _poolAdmin == _candidateAdmin && _candidateAdmin == _treasuryAddr,
      "CandidateStaking: three interaction addresses must be of the same"
    );

    address[] memory _diffAddrs = new address[](3);
    _diffAddrs[0] = _poolAdmin;
    _diffAddrs[1] = _consensusAddr;
    _diffAddrs[2] = _bridgeOperatorAddr;
    require(
      !AddressArrayUtils.hasDuplicate(_diffAddrs),
      "CandidateStaking: three operation addresses must be distinct"
    );

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
    require(_amount <= _pool.stakingAmount, "CandidateStaking: insufficient staking amount");
    require(
      _pool.lastDelegatingTimestamp[_requester] + _cooldownSecsToUndelegate <= block.timestamp,
      "CandidateStaking: unstake too early"
    );

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
