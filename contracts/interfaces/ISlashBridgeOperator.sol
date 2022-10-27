// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ISlashBridgeOperator {
  /**
   * @dev Emitted when the configs to slash bridge operator is updated. See the method
   * `getBridgeOperatorMissingConfigs` for param details.
   */
  event BridgeOperatorSlashConfigsUpdated(
    uint256 missingVotesRatioTier1,
    uint256 missingVotesRatioTier2,
    uint256 jailDurationForMissingVotesRatioTier2
  );

  /**
   * @dev Returns the configs related to bridge operator slashing.
   *
   * @return _missingVotesRatioTier1 The bridge reward will be deprecated if (s)he missed more than this ratio.
   * @return _missingVotesRatioTier2 The bridge reward and mining reward will be deprecated and the corresponding
   * block producer will be put in jail if (s)he misses more than this ratio.
   * @return _jailDurationForMissingVotesRatioTier2 The number of blocks to jail the corresponding block producer when
   * its bridge operator is slashed tier-2.
   *
   */
  function getBridgeOperatorMissingConfigs()
    external
    view
    returns (
      uint256 _missingVotesRatioTier1,
      uint256 _missingVotesRatioTier2,
      uint256 _jailDurationForMissingVotesRatioTier2
    );

  /**
   * @dev Sets the configs to slash bridge operators.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the event `BridgeOperatorSlashConfigsUpdated`.
   *
   * @param _ratioTier1 The bridge reward will be deprecated if (s)he missed more than this ratio. Values 0-10,000 map
   * to 0%-100%.
   * @param _ratioTier2 The bridge reward and mining reward will be deprecated and the corresponding block producer will
   * be put in jail if (s)he misses more than this ratio. Values 0-10,000 map to 0%-100%.
   * @param _jailDurationTier2 The number of blocks to jail the corresponding block producer when its bridge operator is
   * slashed tier-2.
   *
   */
  function setBridgeOperatorSlashConfigs(
    uint256 _ratioTier1,
    uint256 _ratioTier2,
    uint256 _jailDurationTier2
  ) external;
}
