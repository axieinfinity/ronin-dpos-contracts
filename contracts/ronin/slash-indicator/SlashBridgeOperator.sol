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
    uint256 _ratioTier1,
    uint256 _ratioTier2,
    uint256 _jailDurationTier2,
    uint256 _skipSlashingThreshold
  ) external override onlyAdmin {
    _setBridgeOperatorSlashingConfigs(_ratioTier1, _ratioTier2, _jailDurationTier2, _skipSlashingThreshold);
  }

  /**
   * @inheritdoc ISlashBridgeOperator
   */
  function execSlashBridgeOperator(
    address _consensusAddr,
    uint256 _tier,
    uint256 _period
  ) external onlyContract(ContractType.VALIDATOR) {
    if (_tier == 1) {
      emit Slashed(_consensusAddr, SlashType.BRIDGE_OPERATOR_MISSING_VOTE_TIER_1, _period);
    } else if (_tier == 2) {
      emit Slashed(_consensusAddr, SlashType.BRIDGE_OPERATOR_MISSING_VOTE_TIER_2, _period);
    }
  }

  /**
   * @dev See `ISlashBridgeOperator-setBridgeOperatorSlashingConfigs`.
   */
  function _setBridgeOperatorSlashingConfigs(
    uint256 _ratioTier1,
    uint256 _ratioTier2,
    uint256 _jailDurationTier2,
    uint256 _skipSlashingThreshold
  ) internal {
    if (_ratioTier1 > _ratioTier2 || _ratioTier1 > _MAX_PERCENTAGE || _ratioTier2 > _MAX_PERCENTAGE) {
      revert ErrInvalidRatios();
    }

    _missingVotesRatioTier1 = _ratioTier1;
    _missingVotesRatioTier2 = _ratioTier2;
    _jailDurationForMissingVotesRatioTier2 = _jailDurationTier2;
    _skipBridgeOperatorSlashingThreshold = _skipSlashingThreshold;
    emit BridgeOperatorSlashingConfigsUpdated(_ratioTier1, _ratioTier2, _jailDurationTier2, _skipSlashingThreshold);
  }
}
