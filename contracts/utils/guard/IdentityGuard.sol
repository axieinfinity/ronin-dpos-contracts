/**
 * @title IdentityGuard
 * @dev The IdentityGuard contract provides modifiers and internal functions
 * to enforce identity checks for contract interactions.
 */
abstract contract IdentityGuard {
  /**
   * @dev Emitted when a contract interaction is attempted but is only allowed for externally owned accounts (EOA).
   * @param addr The address of the contract that attempted the interaction.
   */
  error ErrOnlyEOA(address addr);

  /**
   * @dev Emitted when a contract interaction is attempted but is restricted for contracts with code.
   * @param addr The address of the contract that attempted the interaction.
   */
  error ErrZeroCodeContract(address addr);

  /**
   * @dev The function signature used for the 'ErrOnlyEOA' error.
   */
  uint256 private constant _ONLY_EOA_ERROR_SIGNATURE = 0xfcee2050;

  /**
   * @dev The function signature used for the 'ErrZeroCodeContract' error.
   */
  uint256 private constant _ZERO_CODE_CONTRACT_ERROR_SIGNATURE = 0x2ff1928c;

  /**
   * @dev Modifier to be used in functions that should only be called by externally owned accounts (EOA).
   * It checks if the message sender is the transaction origin (EOA).
   * If not, it reverts the transaction with the 'ErrOnlyEOA' error.
   */
  modifier onlyEOA() virtual {
    _requireEOA();
    _;
  }

  /**
   * @dev Modifier to be used in functions that should only be called by other contracts.
   * It checks if the calling contract has code.
   * If not, it reverts the transaction with the 'ErrZeroCodeContract' error.
   */
  modifier onlyProxy() virtual {
    _requireHasCode(msg.sender);
    _;
  }

  /**
   * @dev Internal function to check if a contract address has code.
   * @param addr The address of the contract to check.
   * @dev Throws an error if the contract address has no code.
   */
  function _requireHasCode(address addr) internal view virtual {
    assembly {
      if iszero(extcodesize(addr)) {
        mstore(0x00, _ZERO_CODE_CONTRACT_ERROR_SIGNATURE)
        mstore(0x20, addr)
        revert(0x1c, 0x24)
      }
    }
  }

  /**
   * @dev Internal function to check if the message sender is an externally owned account (EOA).
   * @dev Throws an error if the message sender is not an EOA.
   */
  function _requireEOA() internal view virtual {
    assembly {
      if iszero(eq(caller(), origin())) {
        mstore(0x00, _ONLY_EOA_ERROR_SIGNATURE)
        mstore(0x20, caller())
        revert(0x1c, 0x24)
      }
    }
  }
}
