// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

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
    _stake(_stakingPool[_consensusAddr], _poolAdmin, _amount);
    emit PoolApproved(_consensusAddr, _poolAdmin);
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
      _amount = _pool.stakingAmount;
      if (_amount > 0) {
        _deductStakingAmount(_pool, _amount);
        if (!_sendRON(payable(_pool.admin), _amount)) {
          emit StakingAmountDeprecated(_pool.addr, _pool.admin, _amount);
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
    poolExists(_consensusAddr)
    onlyPoolAdmin(_stakingPool[_consensusAddr], msg.sender)
  {
    _validatorContract.requestRevokeCandidate(_consensusAddr, _secsForRevoking);
  }

  /**
   * @dev Proposes a candidate to become a validator.
   *
   * Requirements:
   * - The pool admin is able to receive RON.
   * - The treasury is able to receive RON.
   * - The amount is larger than or equal to the minimum validator staking amount `minValidatorStakingAmount()`.
   *
   * @param _candidateAdmin the candidate admin will be stored in the validator contract, used for calling function that affects
   * to its candidate. IE: scheduling maintenance.
   *
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

    _validatorContract.grantValidatorCandidate(
      _candidateAdmin,
      _consensusAddr,
      _treasuryAddr,
      _bridgeOperatorAddr,
      _commissionRate
    );
  }

  /**
   * @dev Stakes for the validator candidate.
   *
   * Requirements:
   * - The address `_requester` must be the pool admin.
   *
   * Emits the `Staked` event.
   *
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
   * @dev Withdraws the staking amount `_amount` for the validator candidate.
   *
   * Requirements:
   * - The address `_requester` must be the pool admin.
   *
   * Emits the `Unstaked` event.
   *
   */
  function _unstake(
    PoolDetail storage _pool,
    address _requester,
    uint256 _amount
  ) internal onlyPoolAdmin(_pool, _requester) {
    require(_amount <= _pool.stakingAmount, "CandidateStaking: insufficient staking amount");
    require(
      _pool.lastDelegatingTimestamp[_requester] + _minSecsToUndelegate <= block.timestamp,
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
   */
  function _deductStakingAmount(PoolDetail storage _pool, uint256 _amount) internal virtual;

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
