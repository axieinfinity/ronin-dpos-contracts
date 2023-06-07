// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IBaseSlash.sol";

interface ISlashBridgeOperator is IBaseSlash {
  /**
   * @dev Error thrown when invalid ratios are provided.
   */
  error ErrInvalidRatios();

  /**
   * @dev Emitted when the configs to slash bridge operator is updated. See the method
   * `getBridgeOperatorSlashingConfigs` for param details.
   */
  event BridgeOperatorSlashingConfigsUpdated(
    uint256 missingVotesRatioTier1,
    uint256 missingVotesRatioTier2,
    uint256 jailDurationForMissingVotesRatioTier2,
    uint256 skipBridgeOperatorSlashingThreshold
  );

  /**
   * @dev Acknowledges bridge operator slash and emit `Slashed` event correspondingly.
   * @param _tier The tier of the slash, in value of {1, 2}, corresponding to `SlashType.BRIDGE_OPERATOR_MISSING_VOTE_TIER_1`
   * and `SlashType.BRIDGE_OPERATOR_MISSING_VOTE_TIER_2`
   *
   * Requirements:
   * - Only validator contract can invoke this method.
   * - Should be called only at the end of period.
   * - Should be called only when there is slash of bridge operator.
   *
   * Emits the event `Slashed`.
   */
  function execSlashBridgeOperator(address _consensusAddr, uint256 _tier, uint256 _period) external;

  /**
   * @dev Returns the configs related to bridge operator slashing.
   *
   * @return _missingVotesRatioTier1 The bridge reward will be deprecated if (s)he missed more than this ratio.
   * @return _missingVotesRatioTier2 The bridge reward and mining reward will be deprecated and the corresponding
   * block producer will be put in jail if (s)he misses more than this ratio.
   * @return _jailDurationForMissingVotesRatioTier2 The number of blocks to jail the corresponding block producer when
   * its bridge operator is slashed tier-2.
   * @return _skipBridgeOperatorSlashingThreshold The threshold to skip slashing the bridge operator in case the total
   * number of votes in the bridge is too small.
   *
   */
  function getBridgeOperatorSlashingConfigs()
    external
    view
    returns (
      uint256 _missingVotesRatioTier1,
      uint256 _missingVotesRatioTier2,
      uint256 _jailDurationForMissingVotesRatioTier2,
      uint256 _skipBridgeOperatorSlashingThreshold
    );

  /**
   * @dev Sets the configs to slash bridge operators.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the event `BridgeOperatorSlashingConfigsUpdated`.
   *
   * @param _ratioTier1 The bridge reward will be deprecated if (s)he missed more than this ratio. Values 0-10,000 map
   * to 0%-100%.
   * @param _ratioTier2 The bridge reward and mining reward will be deprecated and the corresponding block producer will
   * be put in jail if (s)he misses more than this ratio. Values 0-10,000 map to 0%-100%.
   * @param _jailDurationTier2 The number of blocks to jail the corresponding block producer when its bridge operator is
   * slashed tier-2.
   * @param _skipSlashingThreshold The threshold to skip slashing the bridge operator in case the total number of votes
   * in the bridge is too small.
   *
   */
  function setBridgeOperatorSlashingConfigs(
    uint256 _ratioTier1,
    uint256 _ratioTier2,
    uint256 _jailDurationTier2,
    uint256 _skipSlashingThreshold
  ) external;
}
