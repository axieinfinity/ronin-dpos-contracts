// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IBaseSlash.sol";

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
   * @dev Slashes for unavailability by increasing the counter of block producer `_consensusAddr`.
   *
   * Requirements:
   * - The method caller is coinbase.
   *
   * Emits the event `Slashed` when the threshold is reached.
   *
   */
  function slashUnavailability(address _consensusAddr) external;

  /**
   * @dev Returns the current unavailability indicator of a block producer.
   */
  function currentUnavailabilityIndicator(address _validator) external view returns (uint256);

  /**
   * @dev Returns the unavailability indicator in the period `_period` of a block producer.
   */
  function getUnavailabilityIndicator(address _validator, uint256 _period) external view returns (uint256);

  /**
   * @dev Returns the configs related to block producer slashing.
   *
   * @return _unavailabilityTier1Threshold The mining reward will be deprecated, if (s)he missed more than this
   * threshold. This threshold is applied for tier-1 and tier-3 slash.
   * @return _unavailabilityTier2Threshold  The mining reward will be deprecated, (s)he will be put in jailed, and will
   * be deducted self-staking if (s)he misses more than this threshold. This threshold is applied for tier-2 slash.
   * @return _slashAmountForUnavailabilityTier2Threshold The amount of RON to deduct from self-staking of a block
   * producer when (s)he is slashed with tier-2 or tier-3.
   * @return _jailDurationForUnavailabilityTier2Threshold The number of blocks to jail a block producer when (s)he is
   * slashed with tier-2 or tier-3.
   *
   */
  function getUnavailabilitySlashingConfigs()
    external
    view
    returns (
      uint256 _unavailabilityTier1Threshold,
      uint256 _unavailabilityTier2Threshold,
      uint256 _slashAmountForUnavailabilityTier2Threshold,
      uint256 _jailDurationForUnavailabilityTier2Threshold
    );

  /**
   * @dev Sets the configs to slash block producers.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the event `BridgeOperatorSlashingConfigsUpdated`.
   *
   * @param _tier1Threshold The mining reward will be deprecated, if (s)he missed more than this threshold.
   * @param _tier2Threshold The mining reward will be deprecated, (s)he will be put in jailed, and will be deducted
   * self-staking if (s)he misses more than this threshold.
   * @param _slashAmountForTier2Threshold The amount of RON to deduct from self-staking of a block producer when (s)he
   * is slashed tier-2.
   * @param _jailDurationForTier2Threshold The number of blocks to jail a block producer when (s)he is slashed tier-2.
   *
   */
  function setUnavailabilitySlashingConfigs(
    uint256 _tier1Threshold,
    uint256 _tier2Threshold,
    uint256 _slashAmountForTier2Threshold,
    uint256 _jailDurationForTier2Threshold
  ) external;
}
