// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/RONTransferHelper.sol";

import "../../utils/CommonErrors.sol";

contract MockForwarderTarget is RONTransferHelper {
  address public owner;
  uint256 public data;

  event TargetWithdrawn(address indexed _origin, address indexed _caller, address indexed _recipient);

  /**
   * @dev Error thrown intentionally for a specific purpose.
   */
  error ErrIntentionally();

  modifier onlyOwner() {
    if (msg.sender != owner) revert ErrUnauthorized(msg.sig, RoleAccess.ADMIN);
    _;
  }

  fallback() external payable {
    _fallback();
  }

  receive() external payable {
    _fallback();
  }

  constructor(address _owner, uint256 _data) payable {
    owner = _owner;
    data = _data;
  }

  function foo(uint256 _data) external onlyOwner {
    data = _data;
  }

  function fooPayable(uint256 _data) external payable onlyOwner {
    data = _data;
  }

  function fooSilentRevert() external view onlyOwner {
    revert();
  }

  function fooCustomErrorRevert() external view onlyOwner {
    revert ErrIntentionally();
  }

  function fooRevert() external view onlyOwner {
    revert("MockForwarderContract: revert intentionally");
  }

  function getBalance() external view returns (uint256) {
    return address(this).balance;
  }

  function withdrawAll() external onlyOwner {
    emit TargetWithdrawn(tx.origin, msg.sender, msg.sender);
    _transferRON(payable(msg.sender), address(this).balance);
  }

  function _fallback() private pure {
    revert("MockForwardTarget: hello from fallback");
  }
}
