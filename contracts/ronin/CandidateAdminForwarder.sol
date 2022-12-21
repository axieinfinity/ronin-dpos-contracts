// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "../extensions/forwarder/Forwarder.sol";
import "../extensions/RONTransferHelper.sol";

contract CandidateAdminForwarder is Forwarder, AccessControlEnumerable, RONTransferHelper {
  /// @dev Moderator of the forwarder role hash
  bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");

  event ForwarderWithdrawn(address indexed _recipient, uint256 _value);

  constructor(address _target, address _admin) Forwarder(_target, _admin) {
    _setupRole(DEFAULT_ADMIN_ROLE, _admin);
  }

  /**
   * @dev Treats the fallback function based on permission of the `msg.sender`:
   * - Admin of forwarder : interact directly with the forwarder,
   * - Has `MODERATOR_ROLE`: forwards the call to the target (the `msg.value` is sent along in the call),
   * - Unauthorized: revert the call.
   */
  fallback() external payable override {
    if (msg.sender == _getAdmin()) {
      return;
    }

    require(hasRole(MODERATOR_ROLE, msg.sender), "Unauthorized call");
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
   * - Only authorized users can call this method.
   */
  function functionCall(bytes memory _data, uint256 _val) external payable override {
    require(hasRole(MODERATOR_ROLE, msg.sender) || msg.sender == _admin(), "Unauthorized call");
    _functionCall(_data, _val);
  }

  /**
   * @dev Withdraws all balance from the forward to the admin.
   *
   * Requirements:
   * - Only forwarder admin can call this method.
   */
  function withdrawAll() external ifAdmin {
    uint256 _value = address(this).balance;
    emit ForwarderWithdrawn(msg.sender, _value);
    _transferRON(payable(msg.sender), _value);
  }
}
