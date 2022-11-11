// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/collections/HasSlashIndicatorContract.sol";
import "../../interfaces/validator/IRoninValidatorSetSlashing.sol";
import "./RoninValidatorSetCommon.sol";

abstract contract RoninValidatorSetSlashing is
  IRoninValidatorSetSlashing,
  HasSlashIndicatorContract,
  RoninValidatorSetCommon
{
  /**
   * @inheritdoc IRoninValidatorSetSlashing
   */
  function execSlash(
    address _validatorAddr,
    uint256 _newJailedUntil,
    uint256 _slashAmount
  ) external override onlySlashIndicatorContract {
    uint256 _period = currentPeriod();
    _miningRewardDeprecatedAtPeriod[_validatorAddr][_period] = true;
    delete _miningReward[_validatorAddr];
    delete _delegatingReward[_validatorAddr];

    if (_newJailedUntil > _jailedUntil[_validatorAddr]) {
      _jailedUntil[_validatorAddr] = _newJailedUntil;
    }

    if (_slashAmount > 0) {
      IStaking(_stakingContract).deductStakingAmount(_validatorAddr, _slashAmount);
    }

    emit ValidatorPunished(_validatorAddr, _period, _jailedUntil[_validatorAddr], _slashAmount, true, false);
  }

  /**
   * @inheritdoc IRoninValidatorSetSlashing
   */
  function execBailOut(address _validatorAddr, uint256 _period) external override onlySlashIndicatorContract {
    /// Note: Removing rewards of validator in `bailOut` function is not needed, since the rewards have been
    /// removed previously in the `slash` function.

    _miningRewardBailoutCutOffAtPeriod[_validatorAddr][_period] = true;
    _miningRewardDeprecatedAtPeriod[_validatorAddr][_period] = false;
    _jailedUntil[_validatorAddr] = block.number - 1;

    emit ValidatorUnjailed(_validatorAddr, _period);
  }
}
