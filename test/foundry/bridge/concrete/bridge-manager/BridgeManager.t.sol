// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17 <0.9.0;

import { Base_Test } from "@ronin/test/Base.t.sol";

import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { MockBridgeManager } from "@ronin/contracts/mocks/ronin/MockBridgeManager.sol";

contract BridgeManager_Unit_Concrete_Test is Base_Test {
  IBridgeManager internal _bridgeManager;
  address[] internal _bridgeOperators;
  address[] internal _governors;
  uint96[] internal _voteWeights;

  function setUp() public virtual {
    address[] memory bridgeOperators = new address[](3);
    bridgeOperators[0] = address(0x10000);
    bridgeOperators[1] = address(0x10001);
    bridgeOperators[2] = address(0x10002);

    address[] memory governors = new address[](3);
    governors[0] = address(0x20000);
    governors[1] = address(0x20001);
    governors[2] = address(0x20002);

    uint96[] memory voteWeights = new uint96[](3);
    voteWeights[0] = 100;
    voteWeights[1] = 100;
    voteWeights[2] = 100;

    for (uint i; i < bridgeOperators.length; i++) {
      _bridgeOperators.push(bridgeOperators[i]);
      _governors.push(governors[i]);
      _voteWeights.push(voteWeights[i]);
    }

    _bridgeManager = new MockBridgeManager(bridgeOperators, governors, voteWeights);
  }
}
