// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../interfaces/staking/IStaking.sol";
import "../../interfaces/validator/IRoninValidatorSet.sol";
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
    uint256 __maxCommissionRate,
    uint256 __cooldownSecsToUndelegate,
    uint256 __waitingSecsToRevoke
  ) external initializer {
    _setValidatorContract(__validatorContract);
    _setMinValidatorStakingAmount(__minValidatorStakingAmount);
    _setMaxCommissionRate(__maxCommissionRate);
    _setCooldownSecsToUndelegate(__cooldownSecsToUndelegate);
    _setWaitingSecsToRevoke(__waitingSecsToRevoke);
  }

  /**
   * @inheritdoc IStaking
   */
  function execRecordRewards(
    address[] calldata _consensusAddrs,
    uint256[] calldata _rewards,
    uint256 _period
  ) external payable override onlyValidatorContract {
    _recordRewards(_consensusAddrs, _rewards, _period);
  }

  /**
   * @inheritdoc IStaking
   */
  function execDeductStakingAmount(address _consensusAddr, uint256 _amount)
    external
    override
    onlyValidatorContract
    returns (uint256 _actualDeductingAmount)
  {
    _actualDeductingAmount = _deductStakingAmount(_stakingPool[_consensusAddr], _amount);
    address payable _validatorContractAddr = payable(validatorContract());
    if (!_unsafeSendRON(_validatorContractAddr, _actualDeductingAmount)) {
      emit StakingAmountDeductFailed(
        _consensusAddr,
        _validatorContractAddr,
        _actualDeductingAmount,
        address(this).balance
      );
    }
  }

  /**
   * @inheritdoc RewardCalculation
   */
  function _currentPeriod() internal view virtual override returns (uint256) {
    return _validatorContract.currentPeriod();
  }

  /**
   * @inheritdoc CandidateStaking
   */
  function _deductStakingAmount(PoolDetail storage _pool, uint256 _amount)
    internal
    override
    returns (uint256 _actualDeductingAmount)
  {
    _actualDeductingAmount = Math.min(_pool.stakingAmount, _amount);

    _pool.stakingAmount -= _actualDeductingAmount;
    _changeDelegatingAmount(_pool, _pool.admin, _pool.stakingAmount, _pool.stakingTotal - _actualDeductingAmount);
    emit Unstaked(_pool.addr, _actualDeductingAmount);
  }
}
