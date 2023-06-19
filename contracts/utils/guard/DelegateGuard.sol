// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title DelegateGuard
 * @dev The DelegateGuard contract provides a modifier and internal functions
 * to control delegate calls in derived contracts.
 */
abstract contract DelegateGuard {
  /**
   * @dev Emitted when a delegate call is attempted but is only allowed for the delegate contract.
   */
  error ErrOnlyDelegate();

  /**
   * @dev Emitted when a delegate call is attempted but is restricted for the delegate contract.
   */
  error ErrDelegateUnallowed();

  address private immutable _self;

  /**
   * @dev Modifier to be used in functions that should only be called via delegate call.
   * It checks if the contract is currently being delegated.
   * If not, it reverts the transaction with the 'ErrOnlyDelegate' error.
   */
  modifier onlyDelegatecall() virtual {
    _requireDelegate();
    _;
  }

  /**
   * @dev Modifier to be used in functions that should not be called via delegate call.
   * It checks if the contract is currently being delegated.
   * If it is, it reverts the transaction with the 'ErrDelegateUnallowed' error.
   */
  modifier nonDelegatecall() virtual {
    _restrictDelegate();
    _;
  }

  /**
   * @dev Constructor function that initializes the DelegateGuard contract.
   * @param self The address of the delegate contract. If address(0) is passed, 'this' contract will be used.
   */
  constructor(address self) {
    _self = self == address(0) ? address(this) : self;
  }

  /**
   * @dev Internal function that checks if the contract is currently being delegated.
   * @return A boolean indicating whether the contract is being delegated or not.
   */
  function _isDelegating() internal view virtual returns (bool) {
    return address(this) != _self;
  }

  /**
   * @dev Internal function that checks if the contract requires a delegate call.
   * If the contract is not currently being delegated, it reverts the transaction
   * with the 'ErrOnlyDelegate' error.
   */
  function _requireDelegate() internal view virtual {
    if (!_isDelegating()) {
      revert ErrOnlyDelegate();
    }
  }

  /**
   * @dev Internal function that checks if the contract restricts delegate calls.
   * If the contract is currently being delegated, it reverts the transaction
   * with the 'ErrDelegateUnallowed' error.
   */
  function _restrictDelegate() internal view virtual {
    if (_isDelegating()) {
      revert ErrDelegateUnallowed();
    }
  }
}
