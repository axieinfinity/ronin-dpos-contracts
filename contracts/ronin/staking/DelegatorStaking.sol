// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../interfaces/staking/IDelegatorStaking.sol";
import "./BaseStaking.sol";

abstract contract DelegatorStaking is BaseStaking, IDelegatorStaking {
  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private ______gap;

  /**
   * @inheritdoc IDelegatorStaking
   */
  function delegate(address poolId) external payable noEmptyValue poolIsActive(poolId) {
    if (isAdminOfActivePool(msg.sender)) revert ErrAdminOfAnyActivePoolForbidden(msg.sender);
    _delegate(_poolDetail[poolId], msg.sender, msg.value);
  }

  /**
   * @inheritdoc IDelegatorStaking
   */
  function undelegate(address poolId, uint256 amount) external nonReentrant {
    address payable delegator = payable(msg.sender);
    _undelegate(_poolDetail[poolId], delegator, amount);
    if (!_sendRON(delegator, amount)) revert ErrCannotTransferRON();
  }

  /**
   * @inheritdoc IDelegatorStaking
   */
  function bulkUndelegate(address[] calldata poolIds, uint256[] calldata amounts) external nonReentrant {
    if (poolIds.length == 0 || poolIds.length != amounts.length) revert ErrInvalidArrays();

    address payable delegator = payable(msg.sender);
    uint256 total;

    for (uint _i = 0; _i < poolIds.length; ) {
      total += amounts[_i];
      _undelegate(_poolDetail[poolIds[_i]], delegator, amounts[_i]);

      unchecked {
        ++_i;
      }
    }

    if (!_sendRON(delegator, total)) revert ErrCannotTransferRON();
  }

  /**
   * @inheritdoc IDelegatorStaking
   */
  function redelegate(
    address consensusAddrSrc,
    address consensusAddrDst,
    uint256 amount
  ) external nonReentrant poolIsActive(consensusAddrDst) {
    address delegator = msg.sender;
    _undelegate(_poolDetail[consensusAddrSrc], delegator, amount);
    _delegate(_poolDetail[consensusAddrDst], delegator, amount);
  }

  /**
   * @inheritdoc IDelegatorStaking
   */
  function claimRewards(address[] calldata consensusAddrList) external override nonReentrant returns (uint256 amount) {
    amount = _claimRewards(msg.sender, consensusAddrList);
    _transferRON(payable(msg.sender), amount);
  }

  /**
   * @inheritdoc IDelegatorStaking
   */
  function delegateRewards(
    address[] calldata consensusAddrList,
    address consensusAddrDst
  ) external override nonReentrant poolIsActive(consensusAddrDst) returns (uint256 amount) {
    if (isAdminOfActivePool(msg.sender)) revert ErrAdminOfAnyActivePoolForbidden(msg.sender);
    return _delegateRewards(msg.sender, consensusAddrList, consensusAddrDst);
  }

  /**
   * @inheritdoc IDelegatorStaking
   */
  function getRewards(address user, address[] calldata poolIds) external view returns (uint256[] memory rewards_) {
    address poolId;
    uint256 period = IRoninValidatorSet(getContract(ContractType.VALIDATOR)).currentPeriod();
    rewards_ = new uint256[](poolIds.length);

    for (uint256 i = 0; i < poolIds.length; ) {
      poolId = poolIds[i];
      rewards_[i] = _getReward(poolId, user, period, getStakingAmount(poolId, user));

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @dev Delegates from a validator address.
   *
   * Requirements:
   * - The delegator is not the pool admin.
   *
   * Emits the `Delegated` event.
   *
   * Note: This function does not verify the `msg.value` with the amount.
   *
   */
  function _delegate(
    PoolDetail storage _pool,
    address delegator,
    uint256 amount
  ) internal anyExceptPoolAdmin(_pool, delegator) {
    _changeDelegatingAmount(_pool, delegator, _pool.delegatingAmount[delegator] + amount, _pool.stakingTotal + amount);
    _pool.lastDelegatingTimestamp[delegator] = block.timestamp;
    emit Delegated(delegator, _pool.id, amount);
  }

  /**
   * @dev Undelegates from a validator address.
   *
   * Requirements:
   * - The delegator is not the pool admin.
   * - The amount is larger than 0.
   * - The delegating amount is larger than or equal to the undelegating amount.
   *
   * Emits the `Undelegated` event.
   *
   * Note: Consider transferring back the amount of RON after calling this function.
   *
   */
  function _undelegate(
    PoolDetail storage _pool,
    address delegator,
    uint256 amount
  ) private anyExceptPoolAdmin(_pool, delegator) {
    if (amount == 0) revert ErrUndelegateZeroAmount();
    if (_pool.delegatingAmount[delegator] < amount) revert ErrInsufficientDelegatingAmount();

    IRoninValidatorSet validatorContract = IRoninValidatorSet(getContract(ContractType.VALIDATOR));
    if (
      validatorContract.isValidatorCandidate(_pool.id) &&
      validatorContract.getCandidateInfo(_pool.id).revokingTimestamp == 0 && // if candidate is not on renunciation
      _pool.lastDelegatingTimestamp[delegator] + _cooldownSecsToUndelegate >= block.timestamp // delegator is still in cooldown
    ) revert ErrUndelegateTooEarly();

    _changeDelegatingAmount(_pool, delegator, _pool.delegatingAmount[delegator] - amount, _pool.stakingTotal - amount);
    emit Undelegated(delegator, _pool.id, amount);
  }

  /**
   * @dev Claims rewards from the pools `_poolAddrList`.
   * Note: This function does not transfer reward to user.
   */
  function _claimRewards(address user, address[] memory poolIds) internal returns (uint256 amount) {
    uint256 period = _currentPeriod();
    for (uint256 i = 0; i < poolIds.length; ) {
      amount += _claimReward(poolIds[i], user, period);

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @dev Claims the rewards and delegates them to the consensus address.
   */
  function _delegateRewards(
    address user,
    address[] calldata poolIds,
    address poolIdDst
  ) internal returns (uint256 amount) {
    amount = _claimRewards(user, poolIds);
    _delegate(_poolDetail[poolIdDst], user, amount);
  }
}
