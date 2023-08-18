// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17 <0.9.0;

import { Base_Test } from "@ronin/test/Base.t.sol";

import { IBridgeTracking } from "@ronin/contracts/interfaces/bridge/IBridgeTracking.sol";

import { MockBridgeTracking } from "@ronin/test/mocks/MockBridgeTracking.sol";

contract BridgeReward_Unit_Concrete_Test is Base_Test {
  IBridgeTracking internal _bridgeTracking;

  function setUp() public virtual {
    _bridgeTracking = new MockBridgeTracking();

    // Label the base test contracts.
    vm.label({ account: address(_bridgeTracking), newLabel: "Bridge Tracking" });
  }
}
