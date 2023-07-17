// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IBridgeSlash, BridgeSlash } from "../../ronin/gateway/BridgeSlash.sol";

contract MockBridgeSlash is BridgeSlash {
  function calcSlashUntilPeriod(
    Tier tier,
    uint256 period,
    uint256 slashUntilPeriod
  ) external pure returns (uint256 newSlashUntilPeriod) {
    newSlashUntilPeriod = _calcSlashUntilPeriod(tier, period, slashUntilPeriod, _getPenaltyDurations());
  }

  function isSlashDurationMetRemovalThreshold(uint256 slashUntilPeriod, uint256 period) external pure returns (bool) {
    return _isSlashDurationMetRemovalThreshold(slashUntilPeriod, period);
  }
}
