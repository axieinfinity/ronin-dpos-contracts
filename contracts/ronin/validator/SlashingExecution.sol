// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/collections/HasContracts.sol";
import "../../interfaces/validator/ISlashingExecution.sol";
import "../../interfaces/staking/IStaking.sol";
import "../../libraries/Math.sol";
import { HasSlashIndicatorDeprecated, HasStakingDeprecated } from "../../libraries/DeprecatedSlots.sol";
import "./storage-fragments/CommonStorage.sol";

abstract contract SlashingExecution is
  ISlashingExecution,
  HasContracts,
  HasSlashIndicatorDeprecated,
  HasStakingDeprecated,
  CommonStorage
{
  /**
   * @inheritdoc ISlashingExecution
   */
  function execSlash(
    address _validatorAddr,
    uint256 _newJailedUntil,
    uint256 _slashAmount,
    bool _cannotBailout
  ) external override onlyContractWithRole(Role.SLASH_INDICATOR_CONTRACT) {
    uint256 _period = currentPeriod();
    _miningRewardDeprecatedAtPeriod[_validatorAddr][_period] = true;

    _totalDeprecatedReward += _miningReward[_validatorAddr] + _delegatingReward[_validatorAddr];

    delete _miningReward[_validatorAddr];
    delete _delegatingReward[_validatorAddr];

    _blockProducerJailedBlock[_validatorAddr] = Math.max(_newJailedUntil, _blockProducerJailedBlock[_validatorAddr]);

    if (_slashAmount > 0) {
      uint256 _actualAmount = IStaking(getContract(Role.STAKING_CONTRACT)).execDeductStakingAmount(
        _validatorAddr,
        _slashAmount
      );
      _totalDeprecatedReward += _actualAmount;
    }

    if (_cannotBailout) {
      _cannotBailoutUntilBlock[_validatorAddr] = Math.max(_newJailedUntil, _cannotBailoutUntilBlock[_validatorAddr]);
    }

    emit ValidatorPunished(
      _validatorAddr,
      _period,
      _blockProducerJailedBlock[_validatorAddr],
      _slashAmount,
      true,
      false
    );
  }

  /**
   * @inheritdoc ISlashingExecution
   */
  function execBailOut(
    address _validatorAddr,
    uint256 _period
  ) external override onlyContractWithRole(Role.SLASH_INDICATOR_CONTRACT) {
    if (block.number <= _cannotBailoutUntilBlock[_validatorAddr]) revert ErrCannotBailout(_validatorAddr);

    // Note: Removing rewards of validator in `bailOut` function is not needed, since the rewards have been
    // removed previously in the `slash` function.
    _miningRewardBailoutCutOffAtPeriod[_validatorAddr][_period] = true;
    _miningRewardDeprecatedAtPeriod[_validatorAddr][_period] = false;
    _blockProducerJailedBlock[_validatorAddr] = block.number - 1;

    emit ValidatorUnjailed(_validatorAddr, _period);
  }
}
