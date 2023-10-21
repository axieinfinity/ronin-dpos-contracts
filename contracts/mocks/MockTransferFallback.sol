// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../extensions/RONTransferHelper.sol";

contract MockPaymentFallback {
  event SafeReceived(address indexed sender, uint256 value);

  /// @dev Fallback function accepts ether transactions.
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

  /// @dev Fallback function accepts ether transactions and set non-zero value to a zero value slot.
  receive() external payable {
    array.push(block.number);
    emit SafeReceived(msg.sender, msg.value);
  }
}

contract MockTransfer is RONTransferHelper {
  uint256 public track;

  constructor() payable {}

  function fooTransfer(address payable _recipient, uint256 _amount, uint256 _gas) external {
    if (_unsafeSendRONLimitGas(_recipient, _amount, _gas)) {
      track++;
    }
  }
}
