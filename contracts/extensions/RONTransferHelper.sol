// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

abstract contract RONTransferHelper {
  /// @dev Error of recipient not accepting RON when transfer RON.
  error ErrRecipientRevert();
  /// @dev Error of sender has insufficient balance.
  error ErrInsufficientBalance();

  /**
   * @dev See `_sendRON`.
   * Reverts if the recipient does not receive RON.
   */
  function _transferRON(address payable _recipient, uint256 _amount) internal {
    if (!_sendRON(_recipient, _amount)) revert ErrRecipientRevert();
  }

  /**
   * @dev Send `_amount` RON to the address `_recipient`.
   * Returns whether the recipient receives RON or not.
   * Reverts once the contract balance is insufficient.
   *
   * Note: consider using `ReentrancyGuard` before calling this function.
   *
   */
  function _sendRON(address payable _recipient, uint256 _amount) internal returns (bool _success) {
    assembly {
      if lt(selfbalance(), _amount) {
        mstore(0x00, 0x08c2348a)
        revert(0x1c, 0x04)
      }
    }
    return _unsafeSendRON(_recipient, _amount);
  }

  /**
   * @dev Unsafe send `_amount` RON to the address `_recipient`. If the sender's balance is insufficient,
   * the call does not revert.
   *
   * Note:
   * - Does not assert whether the balance of sender is sufficient.
   * - Does not assert whether the recipient accepts RON.
   * - Consider using `ReentrancyGuard` before calling this function.
   *
   */
  function _unsafeSendRON(address _recipient, uint256 _amount) internal returns (bool _success) {
    /// @solidity memory-safe-assembly
    assembly {
      // Transfer the RON and check if it succeeded or not.
      _success := call(gas(), _recipient, _amount, 0, 0, 0, 0)
    }
  }

  /**
   * @dev Same purpose with {_unsafeSendRON(address,uin256)} but containing gas limit stipend forwarded in the call.
   */
  function _unsafeSendRON(
    address _recipient,
    uint256 _amount,
    uint256 _gas
  ) internal returns (bool _success) {
    /// @solidity memory-safe-assembly
    assembly {
      // Transfer the RON and check if it succeeded or not.
      _success := call(_gas, _recipient, _amount, 0, 0, 0, 0)
    }
  }
}
