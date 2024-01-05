// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/consumers/PercentageConsumer.sol";
import "../../extensions/collections/HasProxyAdmin.sol";
import "../../extensions/collections/HasContracts.sol";
import { HasValidatorDeprecated } from "../../utils/DeprecatedSlots.sol";

abstract contract DeprecatedSlashBridgeOperator is
  HasProxyAdmin,
  HasContracts,
  HasValidatorDeprecated,
  PercentageConsumer
{
  /**
   * @dev The bridge operators will be deprecated reward if (s)he missed more than the ratio.
   * Values 0-10,000 map to 0%-100%.
   */
  uint256 private ____deprecatedMissingVotesRatioTier1;
  /**
   * @dev The bridge operators will be deprecated all rewards including bridge reward and mining reward if (s)he missed
   * more than the ratio. Values 0-10,000 map to 0%-100%.
   */
  uint256 private ____deprecatedMissingVotesRatioTier2;
  /// @dev The number of blocks to jail the corresponding block producer when its bridge operator is slashed tier-2.
  uint256 private ____deprecatedJailDurationForMissingVotesRatioTier2;
  /// @dev The threshold to skip slashing the bridge operator in case the total number of votes in the bridge is too small.
  uint256 private ____deprecatedSkipBridgeOperatorSlashingThreshold;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private ______gap;
}
