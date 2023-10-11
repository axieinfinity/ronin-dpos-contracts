// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17 <0.9.0;

import { Base_Test } from "@ronin/test/Base.t.sol";

import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { IBridgeTracking } from "@ronin/contracts/interfaces/bridge/IBridgeTracking.sol";
import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { IBridgeReward } from "@ronin/contracts/interfaces/bridge/IBridgeReward.sol";
import { IBridgeSlash } from "@ronin/contracts/interfaces/bridge/IBridgeSlash.sol";

import { BridgeReward } from "@ronin/contracts/ronin/gateway/BridgeReward.sol";

import { MockBridgeTracking } from "@ronin/test/mocks/MockBridgeTracking.sol";
import { MockBridgeManager } from "@ronin/test/mocks/MockBridgeManager.sol";
import { MockBridgeSlash } from "@ronin/test/mocks/MockBridgeSlash.sol";
import { MockValidatorSet } from "@ronin/test/mocks/MockValidatorSet.sol";
import { Users } from "@ronin/test/utils/Types.sol";

contract BridgeReward_Unit_Concrete_Test is Base_Test {
  BridgeReward internal _bridgeReward;
  address internal _proxyAdmin;
  uint256 internal _rewardPerPeriod;

  IBridgeTracking internal _bridgeTracking;
  IBridgeManager internal _bridgeManager;
  IBridgeSlash internal _bridgeSlash;
  MockValidatorSet internal _validatorSetContract;

  Users internal _users;

  function setUp() public virtual {
    // Create users for testing.
    _users = Users({ alice: createUser("Alice") });

    _proxyAdmin = vm.addr(1);
    _rewardPerPeriod = 50_000;

    address bridgeRewardImpl = address(new BridgeReward());

    // Deploy the dependencies and mocks for testing contract
    _bridgeReward = BridgeReward(
      address(
        new TransparentUpgradeableProxyV2{ value: _rewardPerPeriod * 1_000_000 }(bridgeRewardImpl, _proxyAdmin, "")
      )
    );
    _bridgeTracking = new MockBridgeTracking();
    _bridgeManager = new MockBridgeManager();
    _bridgeSlash = new MockBridgeSlash();
    _validatorSetContract = new MockValidatorSet();

    _validatorSetContract.setPeriod(1337);

    // Initialize current on testing contract
    _bridgeReward.initialize({
      bridgeManagerContract: address(_bridgeManager),
      bridgeTrackingContract: address(_bridgeTracking),
      bridgeSlashContract: address(_bridgeSlash),
      validatorSetContract: address(_validatorSetContract),
      dposGA: makeAccount("dposGA").addr,
      rewardPerPeriod: _rewardPerPeriod
    });

    vm.prank(makeAccount("dposGA").addr);
    _bridgeReward.initializeREP2();

    // Label the base test contracts.
    vm.label({ account: address(_bridgeReward), newLabel: "Bridge Reward" });
    vm.label({ account: address(_bridgeManager), newLabel: "Bridge Manager" });
    vm.label({ account: address(_bridgeTracking), newLabel: "Bridge Tracking" });
    vm.label({ account: address(_bridgeSlash), newLabel: "Bridge Slash" });
    vm.label({ account: address(_validatorSetContract), newLabel: "Validator Set Contract" });
    vm.label({ account: address(_proxyAdmin), newLabel: "Proxy Admin" });
  }

  /// @dev Generates a user, labels its address, and funds it with test assets.
  function createUser(string memory name) internal returns (address payable) {
    address payable user = payable(makeAddr(name));
    vm.deal({ account: user, newBalance: 100 ether });
    return user;
  }
}
