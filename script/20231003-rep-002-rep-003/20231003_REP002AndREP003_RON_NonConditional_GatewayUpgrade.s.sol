// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StdStyle } from "forge-std/StdStyle.sol";

import "./20231003_REP002AndREP003_RON_NonConditional_Wrapup2Periods.s.sol";
import { BridgeRewardDeploy } from "./contracts/BridgeRewardDeploy.s.sol";
import { BridgeSlashDeploy } from "./contracts/BridgeSlashDeploy.s.sol";
import { RoninBridgeManagerDeploy } from "./contracts/RoninBridgeManagerDeploy.s.sol";

import { RoninGatewayV3 } from "@ronin/contracts/ronin/gateway/RoninGatewayV3.sol";
import { BridgeReward } from "@ronin/contracts/ronin/gateway/BridgeReward.sol";
import { BridgeSlash } from "@ronin/contracts/ronin/gateway/BridgeSlash.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { BridgeTracking } from "@ronin/contracts/ronin/gateway/BridgeTracking.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";

contract Simulation_20231003_REP002AndREP003_RON_NonConditional_GatewayUpgrade is
  Simulation__20231003_UpgradeREP002AndREP003_RON_NonConditional_Wrapup2Periods
{
  function run() public virtual override trySetUp {
    Simulation__20231003_UpgradeREP002AndREP003_Base.run();

    // -------------- Day #1 --------------------
    _deployGatewayContracts();

    // -------------- Day #2 (execute proposal on ronin) --------------------
    // _fastForwardToNextDay();
    // _wrapUpEpoch();

    vm.warp(block.timestamp + 3 seconds);
    vm.roll(block.number + 1);

    _upgradeDPoSContracts();
    _upgradeGatewayContracts();
    _callInitREP2InGatewayContracts();
    // _changeAdminOfGatewayContracts();

    // -- done execute proposal

    // Deposit for
    vm.warp(block.timestamp + 3 seconds);
    vm.roll(block.number + 1);
    // _depositFor("after-upgrade-REP2");
    // _dummySwitchNetworks();
    _depositForOnlyOnRonin("after-upgrade-REP2");

    _fastForwardToNextEpoch();
    vm.warp(block.timestamp + 3 seconds);
    vm.roll(block.number + 1);
    _depositForOnlyOnRonin("after-upgrade-REP2_a");

    _fastForwardToNextEpoch();
    vm.warp(block.timestamp + 3 seconds);
    vm.roll(block.number + 1);
    _depositForOnlyOnRonin("after-upgrade-REP2_b");

    // -------------- End of Day #2 --------------------

    // - wrap up period
    _fastForwardToNextDay();
    _wrapUpEpoch();

    vm.warp(block.timestamp + 3 seconds);
    vm.roll(block.number + 1);
    _depositForOnlyOnRonin("after-wrapup-Day2"); // share bridge reward here
    // _depositFor("after-DAY2");

    _fastForwardToNextEpoch();
    vm.warp(block.timestamp + 3 seconds);
    vm.roll(block.number + 1);
    _depositForOnlyOnRonin("after-wrapup-Day2_a");

    // - deposit for

    // -------------- End of Day #3 --------------------
    // - wrap up period
    _fastForwardToNextDay();
    _wrapUpEpoch();

    vm.warp(block.timestamp + 3 seconds);
    vm.roll(block.number + 1);
    _depositForOnlyOnRonin("after-wrapup-Day3"); // share bridge reward here
  }

  /**
   * @dev Tasks:
   * - Deploy BridgeReward
   * - Deploy BridgeSlash
   * - Deploy RoninBridgeManager
   * - Top up for BridgeReward
   */
  function _deployGatewayContracts() internal {
    console2.log("> ", StdStyle.blue("_deployGatewayContracts"), "...");

    uint256 bridgeManagerNonce = vm.getNonce(_sender) + 4;
    address expectedRoninBridgeManager = computeCreateAddress(_sender, bridgeManagerNonce);

    _bridgeSlash = BridgeSlash(
      new BridgeSlashDeploy()
        .overrideArgs(
          abi.encodeCall(
            BridgeSlash.initialize,
            (
              address(_validatorSet),
              expectedRoninBridgeManager,
              address(_bridgeTracking),
              address(_roninGovernanceAdmin)
            )
          )
        )
        .run()
    );

    _bridgeReward = BridgeReward(
      new BridgeRewardDeploy()
        .overrideArgs(
          abi.encodeCall(
            BridgeReward.initialize,
            (
              expectedRoninBridgeManager,
              address(_bridgeTracking),
              address(_bridgeSlash),
              address(_validatorSet),
              address(_roninGovernanceAdmin),
              1337_133
            )
          )
        )
        .run()
    );

    RoninBridgeManager actualRoninBridgeManager = new RoninBridgeManagerDeploy().run();
    assertEq(address(actualRoninBridgeManager), expectedRoninBridgeManager);
    _roninBridgeManager = actualRoninBridgeManager;

    _bridgeReward.receiveRON{ value: 100 ether }();
  }

  /**
   * @dev Tasks:
   * - Upgrade RoninGatewayV3
   * - Upgrade BridgeTracking
   */
  function _upgradeGatewayContracts() internal {
    console2.log("> ", StdStyle.blue("_upgradeGatewayContracts"), "...");

    {
      _upgradeProxy(ContractKey.RoninGatewayV3, abi.encodeCall(RoninGatewayV3.initializeV2, ()));
      _roninGateway.initializeV3(address(_roninBridgeManager));
    }

    {
      _bridgeTracking.initializeV3({
        bridgeManager: address(_roninBridgeManager),
        bridgeSlash: address(_bridgeSlash),
        bridgeReward: address(_bridgeReward),
        dposGA: address(_roninGovernanceAdmin)
      });
    }
  }

  function _callInitREP2InGatewayContracts() internal {
    vm.startPrank(address(_roninGovernanceAdmin));
    TransparentUpgradeableProxyV2(payable(address(_bridgeReward))).functionDelegateCall(
      abi.encodeCall(BridgeReward.initializeREP2, ())
    );
    TransparentUpgradeableProxyV2(payable(address(_bridgeTracking))).functionDelegateCall(
      abi.encodeCall(BridgeReward.initializeREP2, ())
    );
    TransparentUpgradeableProxyV2(payable(address(_bridgeSlash))).functionDelegateCall(
      abi.encodeCall(BridgeReward.initializeREP2, ())
    );
    vm.stopPrank();
  }
}
