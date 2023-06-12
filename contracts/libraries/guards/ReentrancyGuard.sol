// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { GuardCore } from "./GuardCore.sol";
import { LibBitSlot, BitSlot } from "../udvts/LibBitSlot.sol";

/**
 * @title ReentrancyGuard
 * @dev A contract that provides protection against reentrancy attacks.
 */
abstract contract ReentrancyGuard is GuardCore {
  using LibBitSlot for BitSlot;

  /**
   * @dev Error message for reentrant function call.
   */
  error ErrNonReentrancy();

  /**
   * @dev Modifier to prevent reentrancy attacks.
   */
  modifier nonReentrant() virtual {
    _beforeEnter();
    _;
    _afterEnter();
  }

  /**
   * @dev Internal function to check and set the reentrancy bit before entering the protected function.
   * @dev Throws an error if the reentrancy bit is already set.
   */
  function _beforeEnter() internal virtual {
    BitSlot _slot = BitSlot.wrap(_guardSlot());
    uint8 _reentrancyBitPos = _getBitPos(GuardType.REENTRANCY_BIT);

    // Check if the reentrancy bit is already set, and revert if it is
    if (_slot.get(_reentrancyBitPos)) revert ErrNonReentrancy();

    // Set the reentrancy bit to true
    _slot.set({ pos: _reentrancyBitPos, bitOn: true });
  }

  /**
   * @dev Internal function to reset the reentrancy bit after exiting the protected function.
   */
  function _afterEnter() internal virtual {
    // Reset the reentrancy bit to false
    BitSlot.wrap(_guardSlot()).set({ pos: _getBitPos(GuardType.REENTRANCY_BIT), bitOn: false });
  }
}
