// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import { ErrorHandler } from "../../libraries/ErrorHandler.sol";

contract Forwarder is AccessControlEnumerable {
  using ErrorHandler for bool;

  /**
   * @dev Error thrown when an invalid forward value is provided.
   */
  error ErrInvalidForwardValue();

  /// @dev Only user with moderator role can invoke {functionCall} method to forward the call to the target.
  bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");

  /**
   * @dev The target contracts must be registerred by the admin before called to. The admin can register the targets at
   * the contract construction or by assigning {TARGET_ROLE} to the target addresses.
   */
  bytes32 public constant TARGET_ROLE = keccak256("TARGET_ROLE");

  /**
   * @dev Initializes the forwarder with an initial target address and a contract admin.
   */
  constructor(address[] memory targets, address admin, address moderator) payable {
    for (uint i = 0; i < targets.length; ) {
      _setupRole(TARGET_ROLE, targets[i]);

      unchecked {
        ++i;
      }
    }
    _setupRole(DEFAULT_ADMIN_ROLE, admin);
    _setupRole(MODERATOR_ROLE, moderator);
  }

  modifier validTarget(address target) {
    _checkRole(TARGET_ROLE, target);
    _;
  }

  /**
   * @dev Receives RON transfer from all addresses.
   */
  fallback() external payable {}

  /**
   * @dev Receives RON transfer from all addresses.
   */
  receive() external payable {}

  /**
   * @dev Forwards the encoded call specified by `_data` to the target. The forwarder attachs `_val` value
   * from the forwarder contract and sends along with the call.
   *
   * Requirements:
   * - Only target with {TARGET_ROLE} can be called to.
   * - Only user with {MODERATOR_ROLE} can call this method.
   */
  function functionCall(
    address target,
    bytes memory data,
    uint256 val
  ) external payable validTarget(target) onlyRole(MODERATOR_ROLE) {
    if (val > address(this).balance) revert ErrInvalidForwardValue();
    _call(target, data, val);
  }

  /**
   * @dev Forwards the current call to `target`.
   *
   * This function does not return to its internal call site, it will return directly to the external caller.
   */
  function _call(address target, bytes memory data, uint256 value) internal {
    (bool success, bytes memory res) = target.call{ value: value }(data);
    success.handleRevert(bytes4(data), res);
  }
}
