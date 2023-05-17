// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/collections/HasSlashIndicatorContract.sol";
import "../../extensions/collections/HasStakingContract.sol";
import "../../interfaces/validator/ISlashingExecution.sol";
import "../../libraries/Math.sol";
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
    uint256 _slashAmount,
    bool _cannotBailout
  ) external override onlySlashIndicatorContract {
    uint256 _period = currentPeriod();
    _miningRewardDeprecatedAtPeriod[_validatorAddr][_period] = true;

    _totalDeprecatedReward += _miningReward[_validatorAddr] + _delegatingReward[_validatorAddr];

    delete _miningReward[_validatorAddr];
    delete _delegatingReward[_validatorAddr];

    _blockProducerJailedBlock[_validatorAddr] = Math.max(_newJailedUntil, _blockProducerJailedBlock[_validatorAddr]);

    if (_slashAmount > 0) {
      //  _totalDeprecatedReward += actualAmount;
      _totalDeprecatedReward += _stakingContract.execDeductStakingAmount(_validatorAddr, _slashAmount);
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
  function execBailOut(address _validatorAddr, uint256 _period) external override onlySlashIndicatorContract {
    if (block.number <= _cannotBailoutUntilBlock[_validatorAddr]) revert ErrCannotBailout(_validatorAddr);

    // Note: Removing rewards of validator in `bailOut` function is not needed, since the rewards have been
    // removed previously in the `slash` function.
    assembly {
      mstore(0x00, _validatorAddr)
      mstore(0x20, _miningRewardBailoutCutOffAtPeriod.slot)
      mstore(0x20, keccak256(0x00, 0x40))
      mstore(0x00, _period)
      let key := keccak256(0x00, 0x40)
      sstore(key, 1)

      mstore(0x00, _validatorAddr)
      mstore(0x20, _miningRewardDeprecatedAtPeriod.slot)
      mstore(0x20, keccak256(0x00, 0x40))
      mstore(0x00, _period)
      key := keccak256(0x00, 0x40)
      sstore(key, 0)

      mstore(0x00, _validatorAddr)
      mstore(0x20, _blockProducerJailedBlock.slot)
      key := keccak256(0x00, 0x40)
      sstore(key, sub(number(), 1))

      mstore(0x00, _period)
      log2(
        0x00,
        0x20,
        /// @dev value is equal to keccak256("ValidatorUnjailed(address,uint256)")
        0x6bb2436cb6b6eb65d5a52fac2ae0373a77ade6661e523ef3004ee2d5524e6c6e,
        _validatorAddr
      )
    }
  }
}
