// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../extensions/RONTransferHelper.sol";
import "hardhat/console.sol";

contract MockPaymentFallback {
  event SafeReceived(address indexed sender, uint256 value);

  /// @dev Fallback function accepts Ether transactions.
  receive() external payable {
    emit SafeReceived(msg.sender, msg.value);
  }
}

contract MockPaymentFallbackExpensive {
  uint[] public array;
  event SafeReceived(address indexed sender, uint256 value);

  constructor() {
    array.push(0);
  }

  /// @dev Fallback function accepts Ether transactions.
  receive() external payable {
    // console.log(gasleft());
    array.push(block.number);
    // console.log(gasleft());
    emit SafeReceived(msg.sender, msg.value);
  }
}

contract MockTransfer is RONTransferHelper {
  uint256 public track;

  constructor() payable {}

  function fooTransfer(
    address payable _recipient,
    uint256 _amount,
    uint256 _gas
  ) external {
    if (_unsafeSendRON(_recipient, _amount, _gas)) {
      track++;
    }
  }
}
