// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../extensions/forwarder/Forwarder.sol";
import "../extensions/RONTransferHelper.sol";

contract CandidateAdminForwarder is Forwarder, RONTransferHelper {
  constructor(address _target, address _admin) Forwarder(_target, _admin) {}

  function withdrawAll() external ifAdmin {
    _transferRON(payable(msg.sender), address(this).balance);
  }
}
