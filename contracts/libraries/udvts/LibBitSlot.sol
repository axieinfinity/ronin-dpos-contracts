// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

type BitSlot is bytes32;

library LibBitSlot {
  /**
   * @dev Returns whether the bit at position `pos`-th of a slot `slot` is set or not.
   */
  function get(BitSlot slot, uint8 pos) internal view returns (bool bitOn) {
    assembly {
      bitOn := and(shr(pos, sload(slot)), 1)
    }
  }

  /**
   * @dev Sets the bit at position `pos`-th of a slot `slot` to be on or off.
   */
  function set(
    BitSlot slot,
    uint8 pos,
    bool bitOn
  ) internal {
    assembly {
      let value := sload(slot)
      let shift := and(pos, 0xff)
      // Isolate the bit at `shift`.
      let bit := and(shr(shift, value), 1)
      // Xor it with `_bitOn`. Results in 1 if both are different, else 0.
      bit := xor(bit, bitOn)
      // Shifts the bit back. Then, xor with value.
      // Only the bit at `shift` will be flipped if they differ.
      // Every other bit will stay the same, as they are xor'ed with zeroes.
      sstore(slot, xor(value, shl(shift, bit)))
    }
  }
}
