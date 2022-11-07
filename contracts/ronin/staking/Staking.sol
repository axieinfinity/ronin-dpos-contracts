// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../interfaces/IStaking.sol";
import "../../interfaces/IRoninValidatorSet.sol";
import "./StakingManager.sol";

contract Staking is IStaking, StakingManager, Initializable {
  /// @dev The minimum threshold for being a validator candidate.
  uint256 internal _minValidatorStakingAmount;
  /// @dev The minium number of periods to undelegate from the last period (s)he delegated.
  uint256 internal _minPeriodsToUndelegate;
  /// @dev The number of periods that the candidate must wait to be revoked and take the self-staking amount back.
  uint256 internal _revokePeriods;

  constructor() {
    _disableInitializers();
  }

  receive() external payable onlyValidatorContract {}

  fallback() external payable onlyValidatorContract {}

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(
    address __validatorContract,
    uint256 __minValidatorStakingAmount,
    uint256 __minPeriodsToUndelegate,
    uint256 __revokePeriods
  ) external initializer {
    _setValidatorContract(__validatorContract);
    _setMinValidatorStakingAmount(__minValidatorStakingAmount);
    _setMinPeriodsToUndelegate(__minPeriodsToUndelegate);
    _setRevokePeriod(__revokePeriods);
  }

  /**
   * @inheritdoc IStaking
   */
  function getStakingPool(address _poolAddr)
    external
    view
    poolExists(_poolAddr)
    returns (
      address _admin,
      uint256 _stakingAmount,
      uint256 _stakingTotal
    )
  {
    PoolDetail storage _pool = _stakingPool[_poolAddr];
    return (_pool.admin, _pool.stakingAmount, _pool.stakingTotal);
  }

  /**
   * @inheritdoc IStaking
   */
  function minValidatorStakingAmount() public view override(IStaking, StakingManager) returns (uint256) {
    return _minValidatorStakingAmount;
  }

  /**
   * @inheritdoc IStaking
   */
  function setMinValidatorStakingAmount(uint256 _threshold) external override onlyAdmin {
    _setMinValidatorStakingAmount(_threshold);
  }

  /**
   * @inheritdoc IStaking
   */
  function setMinPeriodsToUndelegate(uint256 _minPeriods) external override onlyAdmin {
    _setMinPeriodsToUndelegate(_minPeriods);
  }

  /**
   * @inheritdoc IStaking
   */
  function setRevokePeriod(uint256 _periods) external override onlyAdmin {
    _setRevokePeriod(_periods);
  }

  function _setMinPeriodsToUndelegate(uint256 _minPeriods) internal {
    // TODO
  }

  function _setRevokePeriod(uint256 _periods) internal {
    // TODO
  }

  /**
   * @inheritdoc IStaking
   */
  function recordRewards(
    uint256 _period,
    address[] calldata _consensusAddrs,
    uint256[] calldata _rewards
  ) external payable onlyValidatorContract {
    _recordRewards(_period, _consensusAddrs, _rewards);
  }

  /**
   * @inheritdoc IStaking
   */
  function deductStakingAmount(address _consensusAddr, uint256 _amount) external onlyValidatorContract {
    return _deductStakingAmount(_stakingPool[_consensusAddr], _amount);
  }

  /**
   * @inheritdoc IStaking
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
        if (!_unsafeSendRON(payable(_pool.admin), _amount)) {
          emit StakingAmountTransferFailed(_pool.addr, _pool.admin, _amount, address(this).balance);
        }
      }
    }

    emit PoolsDeprecated(_pools);
  }

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
   * @inheritdoc RewardCalculation
   */
  function _currentPeriod() internal view virtual override returns (uint256) {
    return IRoninValidatorSet(_validatorContract).currentPeriod();
  }

  /**
   * @dev Deducts from staking amount of the validator `_consensusAddr` for `_amount`.
   *
   * Emits the event `Unstaked`.
   *
   */
  function _deductStakingAmount(PoolDetail storage _pool, uint256 _amount) internal {
    _amount = Math.min(_pool.stakingAmount, _amount);

    _pool.stakingAmount -= _amount;
    _changeDelegatingAmount(_pool, _pool.admin, _pool.stakingAmount, _pool.stakingTotal - _amount);
    emit Unstaked(_pool.addr, _amount);
  }

  function _minPeriodsToUndelegate000() internal virtual override returns (uint256) { return _minPeriodsToUndelegate; }
}
