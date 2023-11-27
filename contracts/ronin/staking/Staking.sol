// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../libraries/Math.sol";
import "../../interfaces/staking/IStaking.sol";
import "../../interfaces/validator/IRoninValidatorSet.sol";
import "./StakingCallback.sol";

contract Staking is IStaking, StakingCallback, Initializable {
  constructor() {
    _disableInitializers();
  }

  receive() external payable onlyContract(ContractType.VALIDATOR) {}

  fallback() external payable onlyContract(ContractType.VALIDATOR) {}

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
    _setContract(ContractType.VALIDATOR, __validatorContract);
    _setMinValidatorStakingAmount(__minValidatorStakingAmount);
    _setCommissionRateRange(0, __maxCommissionRate);
    _setCooldownSecsToUndelegate(__cooldownSecsToUndelegate);
    _setWaitingSecsToRevoke(__waitingSecsToRevoke);
  }

  /**
   * @dev Initializes the contract storage V2.
   */
  function initializeV2() external reinitializer(2) {
    _setContract(ContractType.VALIDATOR, ______deprecatedValidator);
    delete ______deprecatedValidator;
  }

  /**
   * @dev Initializes the contract storage V3.
   */
  function initializeV3(address __profileContract) external reinitializer(3) {
    _setContract(ContractType.PROFILE, __profileContract);
  }

  /**
   * @inheritdoc IStaking
   */
  function execRecordRewards(
    address[] calldata poolIds,
    uint256[] calldata rewards,
    uint256 period
  ) external payable override onlyContract(ContractType.VALIDATOR) {
    _recordRewards(poolIds, rewards, period);
  }

  /**
   * @inheritdoc IStaking
   */
  function execDeductStakingAmount(
    address poolId,
    uint256 amount
  ) external override onlyContract(ContractType.VALIDATOR) returns (uint256 actualDeductingAmount_) {
    actualDeductingAmount_ = _deductStakingAmount(_poolDetail[poolId], amount);
    address payable validatorContractAddr = payable(msg.sender);
    if (!_unsafeSendRON(validatorContractAddr, actualDeductingAmount_)) {
      emit StakingAmountDeductFailed(poolId, validatorContractAddr, actualDeductingAmount_, address(this).balance);
    }
  }

  /**
   * @inheritdoc RewardCalculation
   */
  function _currentPeriod() internal view virtual override returns (uint256) {
    return IRoninValidatorSet(getContract(ContractType.VALIDATOR)).currentPeriod();
  }

  /**
   * @inheritdoc CandidateStaking
   */
  function _deductStakingAmount(
    PoolDetail storage _pool,
    uint256 amount
  ) internal override returns (uint256 actualDeductingAmount_) {
    actualDeductingAmount_ = Math.min(_pool.stakingAmount, amount);

    _pool.stakingAmount -= actualDeductingAmount_;
    _changeDelegatingAmount(
      _pool,
      _pool.__shadowedPoolAdmin,
      _pool.stakingAmount,
      Math.subNonNegative(_pool.stakingTotal, actualDeductingAmount_)
    );
    emit Unstaked(_pool.pid, actualDeductingAmount_);
  }
}
