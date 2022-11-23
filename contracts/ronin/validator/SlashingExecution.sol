// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/collections/HasSlashIndicatorContract.sol";
import "../../extensions/collections/HasStakingContract.sol";
import "../../interfaces/validator/ISlashingExecution.sol";
import "./storage-fragments/CommonStorage.sol";

abstract contract SlashingExecution is
  ISlashingExecution,
  HasSlashIndicatorContract,
  HasStakingContract,
  CommonStorage
{
  /**
   * @inheritdoc ISlashingExecution
   */
  function execSlash(
    address _validatorAddr,
    uint256 _newJailedUntil,
    uint256 _slashAmount
  ) external override onlySlashIndicatorContract {
    uint256 _period = currentPeriod();
    _miningRewardDeprecatedAtPeriod[_validatorAddr][_period] = true;

    _totalDeprecatedReward += _miningReward[_validatorAddr] + _delegatingReward[_validatorAddr];

    delete _miningReward[_validatorAddr];
    delete _delegatingReward[_validatorAddr];

    if (_newJailedUntil > _jailedUntil[_validatorAddr]) {
      _jailedUntil[_validatorAddr] = _newJailedUntil;
    }

    if (_slashAmount > 0) {
      _stakingContract.deductStakingAmount(_validatorAddr, _slashAmount);
    }

    emit ValidatorPunished(_validatorAddr, _period, _jailedUntil[_validatorAddr], _slashAmount, true, false);
  }

  /**
   * @inheritdoc ISlashingExecution
   */
  function execBailOut(address _validatorAddr, uint256 _period) external override onlySlashIndicatorContract {
    // Note: Removing rewards of validator in `bailOut` function is not needed, since the rewards have been
    // removed previously in the `slash` function.
    _miningRewardBailoutCutOffAtPeriod[_validatorAddr][_period] = true;
    _miningRewardDeprecatedAtPeriod[_validatorAddr][_period] = false;
    _jailedUntil[_validatorAddr] = block.number - 1;

    emit ValidatorUnjailed(_validatorAddr, _period);
  }
}
