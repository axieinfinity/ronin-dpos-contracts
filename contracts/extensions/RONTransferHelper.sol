// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

abstract contract RONTransferHelper {
  /// @dev Error of sender has insufficient balance.
  error ErrInsufficientBalance(bytes4 msgSig, uint256 currentBalance, uint256 sendAmount);
  /// @dev Error of recipient not accepting RON when transfer RON.
  error ErrRecipientRevert(bytes4 msgSig);

  /**
   * @dev See `_sendRON`.
   * Reverts if the recipient does not receive RON.
   */
  function _transferRON(address payable recipient, uint256 amount) internal {
    if (!_sendRON(recipient, amount)) revert ErrRecipientRevert(msg.sig);
  }

  /**
   * @dev Send `amount` RON to the address `recipient`.
   * Returns whether the recipient receives RON or not.
   * Reverts once the contract balance is insufficient.
   *
   * Note: consider using `ReentrancyGuard` before calling this function.
   *
   */
  function _sendRON(address payable recipient, uint256 amount) internal returns (bool success) {
    if (address(this).balance < amount) revert ErrInsufficientBalance(msg.sig, address(this).balance, amount);
    return _unsafeSendRON(recipient, amount);
  }

  /**
   * @dev Unsafe send `amount` RON to the address `recipient`. If the sender's balance is insufficient,
   * the call does not revert.
   *
   * Note:
   * - Does not assert whether the balance of sender is sufficient.
   * - Does not assert whether the recipient accepts RON.
   * - Consider using `ReentrancyGuard` before calling this function.
   *
   */
  function _unsafeSendRON(address payable recipient, uint256 amount) internal returns (bool success) {
    (success, ) = recipient.call{ value: amount }("");
  }

  /**
   * @dev Same purpose with {_unsafeSendRONLimitGas(address,uin256)} but containing gas limit stipend forwarded in the call.
   */
  function _unsafeSendRONLimitGas(
    address payable recipient,
    uint256 amount,
    uint256 gas
  ) internal returns (bool success) {
    (success, ) = recipient.call{ value: amount, gas: gas }("");
  }
}
