// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/collections/HasContracts.sol";
import "../../interfaces/validator/ISlashingExecution.sol";
import "../../interfaces/staking/IStaking.sol";
import "../../libraries/Math.sol";
import { HasSlashIndicatorDeprecated, HasStakingDeprecated } from "../../utils/DeprecatedSlots.sol";
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
    address validatorAddr,
    uint256 newJailedUntil,
    uint256 slashAmount,
    bool cannotBailout
  ) external override onlyContract(ContractType.SLASH_INDICATOR) {
    uint256 period = currentPeriod();
    _miningRewardDeprecatedAtPeriod[validatorAddr][period] = true;

    _totalDeprecatedReward += _miningReward[validatorAddr] + _delegatingReward[validatorAddr];

    delete _miningReward[validatorAddr];
    delete _delegatingReward[validatorAddr];

    _blockProducerJailedBlock[validatorAddr] = Math.max(newJailedUntil, _blockProducerJailedBlock[validatorAddr]);

    if (slashAmount > 0) {
      uint256 _actualAmount = IStaking(getContract(ContractType.STAKING)).execDeductStakingAmount(
        validatorAddr,
        slashAmount
      );
      _totalDeprecatedReward += _actualAmount;
    }

    if (cannotBailout) {
      _cannotBailoutUntilBlock[validatorAddr] = Math.max(newJailedUntil, _cannotBailoutUntilBlock[validatorAddr]);
    }

    emit ValidatorPunished(validatorAddr, period, _blockProducerJailedBlock[validatorAddr], slashAmount, true, false);
  }

  /**
   * @inheritdoc ISlashingExecution
   */
  function execBailOut(
    address validatorAddr,
    uint256 period
  ) external override onlyContract(ContractType.SLASH_INDICATOR) {
    if (block.number <= _cannotBailoutUntilBlock[validatorAddr]) revert ErrCannotBailout(validatorAddr);

    // Note: Removing rewards of validator in `bailOut` function is not needed, since the rewards have been
    // removed previously in the `slash` function.
    _miningRewardBailoutCutOffAtPeriod[validatorAddr][period] = true;
    _miningRewardDeprecatedAtPeriod[validatorAddr][period] = false;
    _blockProducerJailedBlock[validatorAddr] = block.number - 1;

    emit ValidatorUnjailed(validatorAddr, period);
  }
}
