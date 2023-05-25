// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library LibBitSlot {
  function get(bytes32 slot, uint8 index) internal view returns (bool isSet) {
    assembly {
      isSet := and(shr(index, sload(slot)), 1)
    }
  }

  function set(
    bytes32 slot,
    uint8 index,
    bool isSet
  ) internal {
    assembly {
      let value := sload(slot)
      let shift := and(index, 0xff)
      // Isolate the bit at `shift`.
      let bit := and(shr(shift, value), 1)
      // Xor it with `shouldSet`. Results in 1 if both are different, else 0.
      bit := xor(bit, isSet)
      // Shifts the bit back. Then, xor with value.
      // Only the bit at `shift` will be flipped if they differ.
      // Every other bit will stay the same, as they are xor'ed with zeroes.
      sstore(slot, xor(value, shl(shift, bit)))
    }
  }
}

abstract contract Slot {
  function _slot() internal pure virtual returns (bytes32);
}

abstract contract DelegateGuard is Slot {
  error AlreadyInitialized();
  error CallTypeRestricted();

  using LibBitSlot for bytes32;

  uint256 internal constant _ORIGINAL_BIT_INDEX = 96;
  uint256 internal constant _INITIALIZED_BIT_INDEX = 95;

  modifier restrictDelegate(bool useDelegate) virtual {
    _restrictDelegate(useDelegate);
    _;
  }

  function _slot() internal pure override returns (bytes32) {
    /// @dev value is equal to keccak256("DelegateGuard.STORAGE_SLOT") - 1
    return 0x3850220c150c27668a9ce863e6d90607733ad9f6ab00603ab19e8368319c9931;
  }

  /// @notice set original address and flip initialized = 1, only use one to enable delegate restriction to work, must be called when initalize/reinitalize
  function _setOriginal() internal virtual {
    bytes32 slot = _slot();

    if (slot.get(uint8(_INITIALIZED_BIT_INDEX))) revert AlreadyInitialized();

    assembly {
      sstore(slot, or(sload(slot), or(shl(_ORIGINAL_BIT_INDEX, address()), shl(_INITIALIZED_BIT_INDEX, 1))))
    }
  }

  function _restrictDelegate(bool useDelegate_) internal view virtual {
    bytes32 slot = _slot();

    bytes4 callTypeRestricted = CallTypeRestricted.selector;

    assembly {
      let original := and(shr(_ORIGINAL_BIT_INDEX, sload(slot)), 0xffffffffffffffffffffffffffffffffffffffff)

      if iszero(xor(eq(original, address()), useDelegate_)) {
        mstore(0x00, callTypeRestricted)
        revert(0x1c, 0x04)
      }
    }
  }
}
