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

  constructor(uint256 _data) payable {
    owner = msg.sender;
    data = _data;
  }

  function foo(uint256 _data) external onlyOwner {
    data = _data;
  }

  function fooPayable(uint256 _data) external onlyOwner {
    data = _data;
  }

  function withdrawAll() external onlyOwner {
    _transferRON(payable(msg.sender), address(this).balance);
  }

  function _fallback() private pure {
    require(false, "MockForwardTarget: not supported fallback");
  }
}
