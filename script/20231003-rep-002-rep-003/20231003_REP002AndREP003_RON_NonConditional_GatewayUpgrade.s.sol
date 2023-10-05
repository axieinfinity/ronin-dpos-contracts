// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StdStyle } from "forge-std/StdStyle.sol";

import "./20231003_REP002AndREP003_RON_NonConditional_Wrapup2Periods.s.sol";
import { BridgeRewardDeploy } from "./contracts/BridgeRewardDeploy.s.sol";
import { BridgeSlashDeploy } from "./contracts/BridgeSlashDeploy.s.sol";
import { RoninBridgeManagerDeploy } from "./contracts/RoninBridgeManagerDeploy.s.sol";

import { RoninGatewayV2 } from "@ronin/contracts/ronin/gateway/RoninGatewayV2.sol";
import { BridgeReward } from "@ronin/contracts/ronin/gateway/BridgeReward.sol";
import { BridgeSlash } from "@ronin/contracts/ronin/gateway/BridgeSlash.sol";
import { RoninBridgeManager } from "@ronin/contracts/ronin/gateway/RoninBridgeManager.sol";
import { BridgeTracking } from "@ronin/contracts/ronin/gateway/BridgeTracking.sol";

contract Simulation_20231003_REP002AndREP003_RON_NonConditional_GatewayUpgrade is
  Simulation__20231003_UpgradeREP002AndREP003_RON_NonConditional_Wrapup2Periods
{
  function run() public virtual override trySetUp {
    Simulation__20231003_UpgradeREP002AndREP003_Base.run();

    // Day #1
    _deployGatewayContracts();

    // Day #2 (execute proposal on ronin)
    // _fastForwardToNextDay();
    // _wrapUpEpoch();

    vm.warp(block.timestamp + 3 seconds);
    vm.roll(block.number + 1);

    // _upgradeDPoSContracts();
    _upgradeGatewayContracts();
    // _callInitREP2InGatewayContracts();
    // _changeAdminOfGatewayContracts();

    // -- done execute proposal

    // // Deposit for

    // End of Day #2
    // - wrap up period
    // - deposit for

    // End of Day #2
    // - wrap up period
  }

  /**
   * @dev Tasks:
   * - Deploy BridgeReward
   * - Deploy BridgeSlash
   * - Deploy RoninBridgeManager
   */
  function _deployGatewayContracts() internal {
    console2.log("> ", StdStyle.blue("_deployGatewayContracts"), "...");

    uint256 bridgeManagerNonce = vm.getNonce(_sender) + 4;
    address expectedRoninBridgeManager = computeCreateAddress(_sender, bridgeManagerNonce);

    new BridgeSlashDeploy()
      .setArgs(
        abi.encodeCall(
          BridgeSlash.initialize,
          (
            _config.getAddressFromCurrentNetwork(ContractKey.RoninValidatorSet),
            expectedRoninBridgeManager,
            _config.getAddressFromCurrentNetwork(ContractKey.BridgeTracking)
          )
        )
      )
      .run();

    new BridgeRewardDeploy()
      .setArgs(
        abi.encodeCall(
          BridgeReward.initialize,
          (
            expectedRoninBridgeManager,
            _config.getAddressFromCurrentNetwork(ContractKey.BridgeTracking),
            _config.getAddressFromCurrentNetwork(ContractKey.BridgeSlash),
            _config.getAddressFromCurrentNetwork(ContractKey.RoninValidatorSet),
            _config.getAddressFromCurrentNetwork(ContractKey.GovernanceAdmin),
            1337_133
          )
        )
      )
      .run();

    RoninBridgeManager actualRoninBridgeManager = new RoninBridgeManagerDeploy().run();
    assertEq(address(actualRoninBridgeManager), expectedRoninBridgeManager);
  }

  /**
   * @dev Tasks:
   * - Upgrade RoninGatewayV2
   * - Upgrade BridgeTracking
   */
  function _upgradeGatewayContracts() internal {
    console2.log("> ", StdStyle.blue("_upgradeGatewayContracts"), "...");

    {
      _roninGateway = RoninGatewayV2(
        _upgradeProxy(ContractKey.RoninGatewayV2, abi.encodeCall(RoninGatewayV2.initializeV2, ()))
      );
      // _roninGateway.initializeV3(address(_roninBridgeManager));
    }

    {
      // _bridgeTracking = BridgeTracking(
      //   _upgradeProxy(ContractKey.BridgeTracking, abi.encodeCall(BridgeTracking.initializeV2, ()))
      // );
      // _bridgeTracking.initializeV3({
      //   bridgeManager: address(_roninBridgeManager),
      //   bridgeSlash: address(_bridgeSlash),
      //   bridgeReward: address(_bridgeReward),
      //   dposGA: address(_roninGovernanceAdmin)
      // });
    }
  }
}
