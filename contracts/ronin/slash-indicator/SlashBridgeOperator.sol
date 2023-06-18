// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/consumers/PercentageConsumer.sol";
import "../../extensions/collections/HasProxyAdmin.sol";
import "../../interfaces/slash-indicator/ISlashBridgeOperator.sol";
import "../../extensions/collections/HasContracts.sol";
import { HasValidatorDeprecated } from "../../utils/DeprecatedSlots.sol";

abstract contract SlashBridgeOperator is
  ISlashBridgeOperator,
  HasProxyAdmin,
  HasContracts,
  HasValidatorDeprecated,
  PercentageConsumer
{
  /**
   * @dev The bridge operators will be deprecated reward if (s)he missed more than the ratio.
   * Values 0-10,000 map to 0%-100%.
   */
  uint256 internal _missingVotesRatioTier1;
  /**
   * @dev The bridge operators will be deprecated all rewards including bridge reward and mining reward if (s)he missed
   * more than the ratio. Values 0-10,000 map to 0%-100%.
   */
  uint256 internal _missingVotesRatioTier2;
  /// @dev The number of blocks to jail the corresponding block producer when its bridge operator is slashed tier-2.
  uint256 internal _jailDurationForMissingVotesRatioTier2;
  /// @dev The threshold to skip slashing the bridge operator in case the total number of votes in the bridge is too small.
  uint256 internal _skipBridgeOperatorSlashingThreshold;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private ______gap;

  /**
   * @inheritdoc ISlashBridgeOperator
   */
  function getBridgeOperatorSlashingConfigs()
    external
    view
    override
    returns (
      uint256 missingVotesRatioTier1_,
      uint256 missingVotesRatioTier2_,
      uint256 jailDurationForMissingVotesRatioTier2_,
      uint256 skipBridgeOperatorSlashingThreshold_
    )
  {
    return (
      _missingVotesRatioTier1,
      _missingVotesRatioTier2,
      _jailDurationForMissingVotesRatioTier2,
      _skipBridgeOperatorSlashingThreshold
    );
  }

  /**
   * @inheritdoc ISlashBridgeOperator
   */
  function setBridgeOperatorSlashingConfigs(
    uint256 ratioTier1,
    uint256 ratioTier2,
    uint256 jailDurationTier2,
    uint256 skipSlashingThreshold
  ) external override onlyAdmin {
    _setBridgeOperatorSlashingConfigs(ratioTier1, ratioTier2, jailDurationTier2, skipSlashingThreshold);
  }

  /**
   * @inheritdoc ISlashBridgeOperator
   */
  function execSlashBridgeOperator(
    address validatorId,
    uint256 tier,
    uint256 period
  ) external onlyContract(ContractType.VALIDATOR) {
    if (tier == 1) {
      emit Slashed(validatorId, SlashType.BRIDGE_OPERATOR_MISSING_VOTE_TIER_1, period);
    } else if (tier == 2) {
      emit Slashed(validatorId, SlashType.BRIDGE_OPERATOR_MISSING_VOTE_TIER_2, period);
    }
  }

  /**
   * @dev See `ISlashBridgeOperator-setBridgeOperatorSlashingConfigs`.
   */
  function _setBridgeOperatorSlashingConfigs(
    uint256 ratioTier1,
    uint256 ratioTier2,
    uint256 jailDurationTier2,
    uint256 skipSlashingThreshold
  ) internal {
    if (ratioTier1 > ratioTier2 || ratioTier1 > _MAX_PERCENTAGE || ratioTier2 > _MAX_PERCENTAGE) {
      revert ErrInvalidRatios();
    }

    _missingVotesRatioTier1 = ratioTier1;
    _missingVotesRatioTier2 = ratioTier2;
    _jailDurationForMissingVotesRatioTier2 = jailDurationTier2;
    _skipBridgeOperatorSlashingThreshold = skipSlashingThreshold;
    emit BridgeOperatorSlashingConfigsUpdated(ratioTier1, ratioTier2, jailDurationTier2, skipSlashingThreshold);
  }
}
