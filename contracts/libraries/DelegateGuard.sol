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

  /// @dev Gas efficient bits layout for contract protection:
  /// - [96..255] `original address`
  /// - [95..96] `initialized bit`
  /// - [0..1] `reentracy bit`
  /// - [1..2] `pause/unpause bit`
  uint256 internal constant _ORIGINAL_BIT_INDEX = 96;
  uint256 internal constant _INITIALIZED_BIT_INDEX = 95;

  /// @dev modifier to restrict delegatecall behavior
  /// @notice when shouldRestrict = true, enforces address(this) != original, else revert
  /// @notice when shouldRestrict = false, enforces address(this) == original, else revert
  modifier restrictDelegate(bool shouldRestrict) virtual {
    _restrictDelegate(shouldRestrict);
    _;
  }

  function _slot() internal pure override returns (bytes32) {
    /// @dev value is equal to keccak256("DelegateGuard.STORAGE_SLOT") - 1
    return 0x3850220c150c27668a9ce863e6d90607733ad9f6ab00603ab19e8368319c9931;
  }

  /// @notice set original address and flip initialized = 1,
  /// only use one to enable delegate restriction to work,
  /// must be called when initalize/reinitalize if using Upgradeable Proxy
  /// must be called in constructor if using immutable contracts
  function _setOriginal() internal virtual {
    bytes32 slot = _slot();
    if (slot.get(uint8(_INITIALIZED_BIT_INDEX))) revert AlreadyInitialized();

    assembly {
      // load full slot
      let data := sload(slot)
      // shift address(this) to [96..255]
      let originalMask := shl(_ORIGINAL_BIT_INDEX, address())
      // shift initialized bit to [95..96]
      let initalizedMask := shl(_INITIALIZED_BIT_INDEX, 1)
      // data = data | originalMask | initializedMask
      sstore(slot, or(data, or(originalMask, initalizedMask)))
    }
  }

  function _restrictDelegate(bool shouldRestrict) internal view virtual {
    bytes32 slot = _slot();
    bytes4 callTypeRestricted = CallTypeRestricted.selector;

    assembly {
      let data := sload(slot)
      let original := shr(_ORIGINAL_BIT_INDEX, data)
      // dirty bytes removal
      original := and(original, 0xffffffffffffffffffffffffffffffffffffffff)

      // if current context differs from original and shouldRestrict flag is false => restrict only normal call allowed => revert
      // if current context differs from original and shouldRestrict flag is true => restrict only delegatecall allowed => pass
      // if current context equals original and shouldRestrict flag is false => restrict only normal call allowed => pass
      // if current context equals original and shouldRestrict flag is true => restrict only delegatecall allowed => revert
      if iszero(xor(eq(original, address()), shouldRestrict)) {
        mstore(0x00, callTypeRestricted)
        revert(0x1c, 0x04)
      }
    }
  }
}
