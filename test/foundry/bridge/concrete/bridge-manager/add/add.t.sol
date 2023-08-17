// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17 <0.9.0;

import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";

import "@ronin/contracts/utils/CommonErrors.sol";
import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";

import { BridgeManager_Unit_Concrete_Test } from "../BridgeManager.t.sol";

contract Add_Unit_Concrete_Test is BridgeManager_Unit_Concrete_Test {
  function setUp() public virtual override {
    BridgeManager_Unit_Concrete_Test.setUp();
    vm.startPrank({ msgSender: address(_bridgeManager) });
  }

  function test_RevertWhen_NotSelfCall() external {
    // Prepare data
    (
      address[] memory bridgeOperators,
      address[] memory governors,
      uint96[] memory voteWeights
    ) = _generateNewOperators();

    // Make the caller not self-call.
    changePrank({ msgSender: _bridgeOperators[0] });

    // Run the test.
    vm.expectRevert(abi.encodeWithSelector(ErrOnlySelfCall.selector, IBridgeManager.addBridgeOperators.selector));
    _bridgeManager.addBridgeOperators(voteWeights, governors, bridgeOperators);
  }

  function _generateNewOperators()
    internal
    pure
    returns (address[] memory bridgeOperators, address[] memory governors, uint96[] memory voteWeights)
  {
    bridgeOperators = new address[](1);
    bridgeOperators[0] = address(0x10003);

    governors = new address[](1);
    governors[0] = address(0x20003);

    voteWeights = new uint96[](1);
    voteWeights[0] = 100;
  }
}
