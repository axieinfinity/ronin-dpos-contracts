// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/RONTransferHelper.sol";

contract MockForwarderTarget is RONTransferHelper {
  address public owner;
  uint256 public data;

  modifier onlyOwner() {
    require(msg.sender == owner, "MockForwarderContract: only owner can call method)");
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

  function getBalance() external view returns (uint256) {
    return address(this).balance;
  }

  function withdrawAll() external onlyOwner {
    _transferRON(payable(msg.sender), address(this).balance);
  }

  function _fallback() private pure {
    revert("MockForwardTarget: hello from fallback");
  }
}
