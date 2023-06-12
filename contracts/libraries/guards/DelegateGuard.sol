// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { GuardCore } from "./GuardCore.sol";
import { LibBitSlot, BitSlot } from "../udvts/LibBitSlot.sol";

/**
 * @title DelegateGuard
 * @dev A contract that provides delegatecall restriction functionality.
 */
abstract contract DelegateGuard is GuardCore {
  using LibBitSlot for BitSlot;

  /**
   * @dev Error message for already initialized contract.
   */
  error ErrAlreadyInitialized();

  /**
   * @dev Error message for restricted call type.
   */
  error ErrCallTypeRestricted();

  modifier onlyDelegate() virtual {
    _checkDelegate(true);
    _;
  }

  modifier nonDelegate() virtual {
    _checkDelegate(false);
    _;
  }

  /**
   * @dev Initializes the origin address and turns on the initialized bit.
   *
   * Note:
   * - Must be called during initialization if using an Upgradeable Proxy.
   * - Must be called in the constructor if using immutable contracts.
   *
   */
  function _initOriginAddress() internal virtual {
    bytes32 _slot = _guardSlot();
    uint8 _initializedBitPos = _getBitPos(GuardType.INITIALIZE_BIT);
    // Check if the contract is already initialized
    if (BitSlot.wrap(_slot).get(_initializedBitPos)) revert ErrAlreadyInitialized();

    uint8 _originBitPos = _getBitPos(GuardType.ORIGIN_ADDRESS);
    assembly {
      // Load the full slot
      let _data := sload(_slot)
      // Shift << address(this) to `_originBitPos`
      let _originMask := shl(_originBitPos, address())
      // Shift << initialized bit to `initializedBitPos`
      let _initializedMask := shl(_initializedBitPos, 1)
      // _data = _data | _originMask | _initializedMask
      sstore(_slot, or(_data, or(_originMask, _initializedMask)))
    }
  }

  /**
   * @dev Internal function to restrict delegatecall based on the current context and the `_mustDelegate` flag.
   * @notice When `_mustDelegate` is true, it enforces that `address(this) != originAddress`, otherwise reverts.
   * When `_mustDelegate` is false, it enforces that `address(this) == originAddress`, otherwise reverts.
   */
  function _checkDelegate(bool _mustDelegate) private view {
    bytes32 _slot = _guardSlot();
    uint8 _originBitPos = _getBitPos(GuardType.ORIGIN_ADDRESS);
    bytes4 _callTypeRestricted = ErrCallTypeRestricted.selector;

    assembly {
      let _data := sload(_slot)
      // Shift >> address(this) to `_originBitPos`
      let _origin := shr(_originBitPos, _data)
      // Dirty bytes removal
      _origin := and(_origin, 0xffffffffffffffffffffffffffffffffffffffff)

      // Check the current context and restrict based on the `_mustDelegate` flag
      // If the current context differs from the origin address and `_mustDelegate` flag is false, restrict only normal calls and revert
      // If the current context differs from the origin address and `_mustDelegate` flag is true, restrict only delegatecall and pass
      // If the current context equals the origin address and `_mustDelegate` flag is false, restrict only normal calls and pass
      // If the current context equals the origin address and `_mustDelegate` flag is true, restrict only delegatecall and revert
      if iszero(xor(eq(_origin, address()), _mustDelegate)) {
        mstore(0x00, _callTypeRestricted)
        revert(0x1c, 0x04)
      }
    }
  }
}
