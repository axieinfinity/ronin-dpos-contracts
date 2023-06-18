// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IBaseSlash.sol";
import { TConsensus } from "../../udvts/Types.sol";

interface ISlashUnavailability is IBaseSlash {
  /**
   * @dev Error thrown when attempting to slash a validator twice or slash more than one validator in one block.
   */
  error ErrCannotSlashAValidatorTwiceOrSlashMoreThanOneValidatorInOneBlock();

  /**
   * @dev Emitted when the configs to slash bridge operator is updated. See the method `getUnavailabilitySlashingConfigs`
   * for param details.
   */
  event UnavailabilitySlashingConfigsUpdated(
    uint256 unavailabilityTier1Threshold,
    uint256 unavailabilityTier2Threshold,
    uint256 slashAmountForUnavailabilityTier2Threshold,
    uint256 jailDurationForUnavailabilityTier2Threshold
  );

  /**
   * @dev Returns the last block that a block producer is slashed for unavailability.
   */
  function lastUnavailabilitySlashedBlock() external view returns (uint256);

  /**
   * @dev Slashes for unavailability by increasing the counter of block producer `consensusAddr`.
   *
   * Requirements:
   * - The method caller is coinbase.
   *
   * Emits the event `Slashed` when the threshold is reached.
   *
   */
  function slashUnavailability(TConsensus consensusAddr) external;

  /**
   * @dev Returns the current unavailability indicator of a block producer.
   */
  function currentUnavailabilityIndicator(TConsensus consensusAddr) external view returns (uint256);

  /**
   * @dev Returns the unavailability indicator in the period `period` of a block producer.
   */
  function getUnavailabilityIndicator(TConsensus consensusAddr, uint256 period) external view returns (uint256);

  /**
   * @dev Returns the configs related to block producer slashing.
   *
   * @return unavailabilityTier1Threshold The mining reward will be deprecated, if (s)he missed more than this
   * threshold. This threshold is applied for tier-1 and tier-3 slash.
   * @return unavailabilityTier2Threshold  The mining reward will be deprecated, (s)he will be put in jailed, and will
   * be deducted self-staking if (s)he misses more than this threshold. This threshold is applied for tier-2 slash.
   * @return slashAmountForUnavailabilityTier2Threshold The amount of RON to deduct from self-staking of a block
   * producer when (s)he is slashed with tier-2 or tier-3.
   * @return jailDurationForUnavailabilityTier2Threshold The number of blocks to jail a block producer when (s)he is
   * slashed with tier-2 or tier-3.
   *
   */
  function getUnavailabilitySlashingConfigs()
    external
    view
    returns (
      uint256 unavailabilityTier1Threshold,
      uint256 unavailabilityTier2Threshold,
      uint256 slashAmountForUnavailabilityTier2Threshold,
      uint256 jailDurationForUnavailabilityTier2Threshold
    );

  /**
   * @dev Sets the configs to slash block producers.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the event `BridgeOperatorSlashingConfigsUpdated`.
   *
   * @param tier1Threshold The mining reward will be deprecated, if (s)he missed more than this threshold.
   * @param tier2Threshold The mining reward will be deprecated, (s)he will be put in jailed, and will be deducted
   * self-staking if (s)he misses more than this threshold.
   * @param slashAmountForTier2Threshold The amount of RON to deduct from self-staking of a block producer when (s)he
   * is slashed tier-2.
   * @param jailDurationForTier2Threshold The number of blocks to jail a block producer when (s)he is slashed tier-2.
   *
   */
  function setUnavailabilitySlashingConfigs(
    uint256 tier1Threshold,
    uint256 tier2Threshold,
    uint256 slashAmountForTier2Threshold,
    uint256 jailDurationForTier2Threshold
  ) external;
}
