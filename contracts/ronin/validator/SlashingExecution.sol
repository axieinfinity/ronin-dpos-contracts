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
    address validatorId,
    uint256 newJailedUntil,
    uint256 slashAmount,
    bool cannotBailout
  ) external override onlyContract(ContractType.SLASH_INDICATOR) {
    uint256 period = currentPeriod();
    _miningRewardDeprecatedAtPeriod[validatorId][period] = true;

    _totalDeprecatedReward += _miningReward[validatorId] + _delegatingReward[validatorId];

    delete _miningReward[validatorId];
    delete _delegatingReward[validatorId];

    _blockProducerJailedBlock[validatorId] = Math.max(newJailedUntil, _blockProducerJailedBlock[validatorId]);

    if (slashAmount > 0) {
      uint256 _actualAmount = IStaking(getContract(ContractType.STAKING)).execDeductStakingAmount(
        validatorId,
        slashAmount
      );
      _totalDeprecatedReward += _actualAmount;
    }

    if (cannotBailout) {
      _cannotBailoutUntilBlock[validatorId] = Math.max(newJailedUntil, _cannotBailoutUntilBlock[validatorId]);
    }

    emit ValidatorPunished(validatorId, period, _blockProducerJailedBlock[validatorId], slashAmount, true, false);
  }

  /**
   * @inheritdoc ISlashingExecution
   */
  function execBailOut(
    address validatorId,
    uint256 period
  ) external override onlyContract(ContractType.SLASH_INDICATOR) {
    if (block.number <= _cannotBailoutUntilBlock[validatorId]) revert ErrCannotBailout(validatorId);

    // Note: Removing rewards of validator in `bailOut` function is not needed, since the rewards have been
    // removed previously in the `slash` function.
    _miningRewardBailoutCutOffAtPeriod[validatorId][period] = true;
    _miningRewardDeprecatedAtPeriod[validatorId][period] = false;
    _blockProducerJailedBlock[validatorId] = block.number - 1;

    emit ValidatorUnjailed(validatorId, period);
  }
}
