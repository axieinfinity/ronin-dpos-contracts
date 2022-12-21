// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../extensions/forwarder/Forwarder.sol";
import "../extensions/RONTransferHelper.sol";

/**
 * @title A vault contract that keeps RON, and behaves as an EOA account to interact with a target contract.
 * @dev There are three roles of interaction:
 * - Admin: top-up and withdraw RON to the vault, cannot forward call to the target.
 * - Moderator: forward all calls to the target, can top-up RON, cannot withdraw RON.
 * - Others: can top-up RON, cannot execute any other actions.
 */
contract VaultForwarder is Forwarder, AccessControl, RONTransferHelper {
  /// @dev Moderator of the forwarder role hash
  bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");

  event ForwarderWithdrawn(address indexed _recipient, uint256 _value);

  constructor(address _target, address _admin) Forwarder(_target, _admin) {
    _setupRole(DEFAULT_ADMIN_ROLE, _admin);
  }

  modifier onlyModerator() {
    require(hasRole(MODERATOR_ROLE, msg.sender), "Forwarder: unauthorized call");
    _;
  }

  modifier adminExecutesOrModeratorForwards() {
    if (msg.sender == _getAdmin()) {
      _;
    } else {
      require(hasRole(MODERATOR_ROLE, msg.sender), "Forwarder: unauthorized call");
      _fallback();
    }
  }

  /**
   * @dev Forwards the call to the target (the `msg.value` is sent along in the call).
   *
   * Requirements:
   * - Only moderator can invoke fallback method.
   */
  fallback() external payable override onlyModerator {
    _fallback();
  }

  /**
   * @dev Receives ether transfer from all addresses.
   */
  receive() external payable override {}

  /**
   * @dev Forwards the encoded call specified by `_data` to the target. The forwarder attachs `_val` value
   * from the forwarder contract and sends along with the call.
   *
   * Requirements:
   * - Only `MODERATOR_ROLE` users can call this method.
   */
  function functionCall(bytes memory _data, uint256 _val) external payable onlyModerator {
    _functionCall(_data, _val);
  }

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
