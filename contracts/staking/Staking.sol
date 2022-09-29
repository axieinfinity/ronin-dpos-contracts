// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/IStaking.sol";
import "../interfaces/IRoninValidatorSet.sol";
import "../libraries/Sorting.sol";
import "./StakingManager.sol";

contract Staking is IStaking, StakingManager, Initializable {
  /// @dev The minimum threshold for being a validator candidate.
  uint256 internal _minValidatorBalance;
  /// @dev Mapping from pool address => period index => indicating the pending reward in the period is sinked or not.
  mapping(address => mapping(uint256 => bool)) internal _pRewardSinked;

  constructor() {
    _disableInitializers();
  }

  receive() external payable onlyValidatorContract {}

  fallback() external payable onlyValidatorContract {}

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(address __validatorContract, uint256 __minValidatorBalance) external initializer {
    _setValidatorContract(__validatorContract);
    _setMinValidatorBalance(__minValidatorBalance);
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
      uint256 _stakedAmount,
      uint256 _totalBalance
    )
  {
    PoolDetail storage _pool = _stakingPool[_poolAddr];
    return (_pool.admin, _pool.stakedAmount, _pool.totalBalance);
  }

  /**
   * @inheritdoc IStaking
   */
  function minValidatorBalance() public view override(IStaking, StakingManager) returns (uint256) {
    return _minValidatorBalance;
  }

  /**
   * @inheritdoc IStaking
   */
  function setMinValidatorBalance(uint256 _threshold) external override onlyAdmin {
    _setMinValidatorBalance(_threshold);
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                              FUNCTIONS FOR VALIDATOR                              //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc IStaking
   */
  function recordReward(address _consensusAddr, uint256 _reward) external payable onlyValidatorContract {
    _recordReward(_consensusAddr, _reward);
  }

  /**
   * @inheritdoc IStaking
   */
  function settleRewardPools(address[] calldata _consensusAddrs) external onlyValidatorContract {
    if (_consensusAddrs.length == 0) {
      return;
    }
    _onPoolsSettled(_consensusAddrs);
  }

  /**
   * @inheritdoc IStaking
   */
  function sinkPendingReward(address _consensusAddr) external onlyValidatorContract {
    uint256 _period = _periodOf(block.number);
    _pRewardSinked[_consensusAddr][_period] = true;
    _sinkPendingReward(_consensusAddr);
  }

  /**
   * @inheritdoc IStaking
   */
  function deductStakedAmount(address _consensusAddr, uint256 _amount) public onlyValidatorContract {
    return _deductStakedAmount(_stakingPool[_consensusAddr], _amount);
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
      _amount = _pool.stakedAmount;
      _deductStakedAmount(_pool, _pool.stakedAmount);
      if (_amount > 0) {
        if (!_sendRON(payable(_pool.admin), _amount)) {
          emit StakedAmountDeprecated(_pool.addr, _pool.admin, _amount);
        }
      }

      delete _stakingPool[_pool.addr];
    }

    emit PoolsDeprecated(_pools);
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                                  HELPER FUNCTIONS                                 //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Sets the minimum threshold for being a validator candidate.
   *
   * Emits the `MinValidatorBalanceUpdated` event.
   *
   */
  function _setMinValidatorBalance(uint256 _threshold) internal {
    _minValidatorBalance = _threshold;
    emit MinValidatorBalanceUpdated(_threshold);
  }

  /**
   * @inheritdoc RewardCalculation
   */
  function _rewardSinked(address _poolAddr, uint256 _period) internal view virtual override returns (bool) {
    return _pRewardSinked[_poolAddr][_period];
  }

  /**
   * @inheritdoc RewardCalculation
   */
  function _periodOf(uint256 _block) internal view virtual override returns (uint256) {
    return IRoninValidatorSet(_validatorContract).periodOf(_block);
  }

  /**
   * @dev Deducts from staked amount of the validator `_consensusAddr` for `_amount`.
   *
   * Emits the event `Unstaked`.
   *
   */
  function _deductStakedAmount(PoolDetail storage _pool, uint256 _amount) internal {
    _amount = Math.min(_pool.stakedAmount, _amount);

    _pool.stakedAmount -= _amount;
    _changeDelegatedAmount(_pool, _pool.admin, _pool.stakedAmount, _pool.totalBalance - _amount);
    emit Unstaked(_pool.addr, _amount);
  }
}
