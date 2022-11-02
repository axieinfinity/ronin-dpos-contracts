// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

abstract contract RONTransferHelper {
  /**
   * @dev See `_sendRON`.
   * Reverts if the recipient does not receive RON.
   */
  function _transferRON(address payable _recipient, uint256 _amount) internal {
    require(_sendRON(_recipient, _amount), "RONTransfer: unable to transfer value, recipient may have reverted");
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
    require(address(this).balance >= _amount, "RONTransfer: insufficient balance");
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
  function _unsafeSendRON(address payable _recipient, uint256 _amount) internal returns (bool _success) {
    (_success, ) = _recipient.call{ value: _amount }("");
  }
}
