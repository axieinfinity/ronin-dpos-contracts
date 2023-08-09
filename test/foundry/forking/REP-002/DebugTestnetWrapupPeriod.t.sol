// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../RoninTest.t.sol";
import { MockPrecompile } from "@ronin/contracts/mocks/MockPrecompile.sol";
import { ITimingInfo } from "@ronin/contracts/interfaces/validator/info-fragments/ITimingInfo.sol";
import { ICoinbaseExecution } from "@ronin/contracts/interfaces/validator/ICoinbaseExecution.sol";

contract DebugTx is RoninTest {
  uint256 internal _roninFork;
  uint256 internal constant FORK_HEIGHT = 0;
  bytes32 internal constant TX = 0x5210f0de49b8a8aa4e8197965c8d3bdaa86177f721b31937ed92b9c06f363299;

  function _createFork() internal override {
    _roninFork = vm.createSelectFork(RONIN_TEST_RPC);
  }

  function _setUp() internal override {
    address mockPrecompile = deployImmutable(
      type(MockPrecompile).name,
      type(MockPrecompile).creationCode,
      EMPTY_PARAM,
      ZERO_VALUE
    );
    vm.etch(address(0x68), mockPrecompile.code);
  }

  function test_Debug_SingleTransaction() external onWhichFork(_roninFork) {
    address coinbase = block.coinbase;
    uint256 numberOfBlocksInEpoch = ITimingInfo(address(RONIN_VALIDATOR_SET_CONTRACT)).numberOfBlocksInEpoch();

    uint256 epochEndingBlockNumber = block.number +
      (numberOfBlocksInEpoch - 1) -
      (block.number % numberOfBlocksInEpoch);
    uint256 nextDayTimestamp = block.timestamp + 1 days;

    console.log(_getProxyImplementation(RONIN_VALIDATOR_SET_CONTRACT));

    // fast forward to next day
    vm.warp(nextDayTimestamp);
    vm.roll(epochEndingBlockNumber);
    vm.prank(coinbase, coinbase);
    ICoinbaseExecution(address(RONIN_VALIDATOR_SET_CONTRACT)).wrapUpEpoch();
  }
}
