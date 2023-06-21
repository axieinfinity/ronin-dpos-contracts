// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ConditionalImplementControl } from "../../../extensions/version-control/ConditionalImplementControl.sol";

contract MockConditionalImplementControl is ConditionalImplementControl {
  uint256 public immutable UPGRADED_AT_BLOCK;

  constructor(
    address proxyStorage_,
    address currentVersion_,
    address newVersion_,
    uint256 upgradedAtBlock
  ) ConditionalImplementControl(proxyStorage_, currentVersion_, newVersion_) {
    UPGRADED_AT_BLOCK = upgradedAtBlock;
  }

  function _isConditionMet() internal view override returns (bool) {
    return block.number >= UPGRADED_AT_BLOCK;
  }
}
