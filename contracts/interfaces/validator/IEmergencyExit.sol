// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IEmergencyExit {
  function unlockFundForEmergencyExitRequest(address _consensusAddr, address payable _recipient) external;
}
