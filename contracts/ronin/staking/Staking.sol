// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../interfaces/staking/IStaking.sol";
import "../../interfaces/IRoninValidatorSet.sol";
import "./CandidateStaking.sol";
import "./DelegatorStaking.sol";

contract Staking is IStaking, CandidateStaking, DelegatorStaking, Initializable {
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
    uint256 __minSecsToUndelegate,
    uint256 __secsForRevoking
  ) external initializer {
    _setValidatorContract(__validatorContract);
    _setMinValidatorStakingAmount(__minValidatorStakingAmount);
    _setMinSecsToUndelegate(__minSecsToUndelegate);
    _setSecsForRevoking(__secsForRevoking);
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
   * @inheritdoc RewardCalculation
   */
  function _currentPeriod() internal view virtual override returns (uint256) {
    return IRoninValidatorSet(_validatorContract).currentPeriod();
  }

  /**
   * @inheritdoc CandidateStaking
   */
  function _deductStakingAmount(PoolDetail storage _pool, uint256 _amount) internal override {
    _amount = Math.min(_pool.stakingAmount, _amount);

    _pool.stakingAmount -= _amount;
    _changeDelegatingAmount(_pool, _pool.admin, _pool.stakingAmount, _pool.stakingTotal - _amount);
    emit Unstaked(_pool.addr, _amount);
  }
}
