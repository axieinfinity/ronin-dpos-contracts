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

  ///////////////////////////////////////////////////////////////////////////////////////
  //                             FUNCTIONS FOR GOVERNANCE                              //
  ///////////////////////////////////////////////////////////////////////////////////////

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
  function deductStakingAmount(address _consensusAddr, uint256 _amount) external onlyValidatorContract {
    PoolDetail storage _pool = _stakingPool[_consensusAddr];
    _unstake(_pool, _pool.admin, _amount);
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
}
