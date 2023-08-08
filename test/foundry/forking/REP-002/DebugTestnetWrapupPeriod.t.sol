// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../RoninTest.t.sol";

import { ICoinbaseExecution } from "@ronin/contracts/interfaces/validator/ICoinbaseExecution.sol";

contract DebugTx is RoninTest {
  uint256 internal _roninFork;
  uint256 internal constant FORK_HEIGHT = 0;
  bytes32 internal constant TX = 0x5210f0de49b8a8aa4e8197965c8d3bdaa86177f721b31937ed92b9c06f363299;

  function _createFork() internal override {
    _roninFork = vm.createSelectFork(RONIN_TEST_RPC);
  }

  function _setUp() internal override {}

  function test_Debug_SingleTransaction() external onWhichFork(_roninFork) {
    address coinbase = block.coinbase;
    vm.warp(1691625733);
    vm.roll(19264999);
    vm.prank(coinbase, coinbase);
    ICoinbaseExecution(address(RONIN_VALIDATOR_SET_CONTRACT)).wrapUpEpoch();
  }
}