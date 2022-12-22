// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../extensions/forwarder/Forwarder.sol";
import "../extensions/RONTransferHelper.sol";

/**
 * @title A vault contract that keeps RON, and behaves as an EOA account to interact with a target contract.
 * @dev There are three roles of interaction:
 * - Admin: top-up and withdraw RON to the vault, cannot forward call to the target.
 * - Moderator: forward all calls to the target, can top-up RON, cannot withdraw RON.
 * - Others: can top-up RON, cannot execute any other actions.
 */
contract VaultForwarder is Forwarder, RONTransferHelper {
  event ForwarderWithdrawn(address indexed _recipient, uint256 _value);

  constructor(address _target, address _admin) Forwarder(_target, _admin) {}

  /**
   * @dev Withdraws all balance from the forward to the admin.
   *
   * Requirements:
   * - Only forwarder admin can call this method.
   */
  function withdrawAll() external adminExecutesOrModeratorForwards {
    uint256 _value = address(this).balance;
    emit ForwarderWithdrawn(msg.sender, _value);
    _transferRON(payable(msg.sender), _value);
  }
}
