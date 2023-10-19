// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2, BaseDeploy, ContractKey } from "script/BaseDeploy.s.sol";
import { BridgeTracking } from "@ronin/contracts/ronin/gateway/BridgeTracking.sol";
import { RoninGovernanceAdmin } from "@ronin/contracts/ronin/RoninGovernanceAdmin.sol";
import { BridgeTrackingRecoveryLogic } from "./contracts/BridgeTrackingRecoveryLogic.sol";
import { BridgeReward } from "@ronin/contracts/ronin/gateway/BridgeReward.sol";
import { TransparentUpgradeableProxyV2 } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";

contract Simulation__20231019_RecoverFund is BaseDeploy {
  function run() public trySetUp {
    address admin = 0x968D0Cd7343f711216817E617d3f92a23dC91c07;
    uint256 balanceBefore = admin.balance;
    console2.log("balanceBefore", balanceBefore);
    RoninGovernanceAdmin governanaceAdmin = RoninGovernanceAdmin(0x946397deDFd2f79b75a72B322944a21C3240c9c3);

    BridgeReward deprecatedBridgeReward = BridgeReward(0x1C952D6717eBFd2E92E5f43Ef7C1c3f7677F007D);

    BridgeTracking bridgeTracking = BridgeTracking(0x3Fb325b251eE80945d3fc8c7692f5aFFCA1B8bC2);

    vm.startPrank(address(governanaceAdmin));
    governanaceAdmin.changeProxyAdmin(address(bridgeTracking), admin);
    deprecatedBridgeReward.initializeREP2();
    vm.stopPrank();

    vm.startPrank(admin);
    address logic = address(new BridgeTrackingRecoveryLogic());
    TransparentUpgradeableProxyV2(payable(address(bridgeTracking))).upgradeTo(logic);
    TransparentUpgradeableProxyV2(payable(address(bridgeTracking))).functionDelegateCall(
      abi.encodeCall(BridgeTrackingRecoveryLogic.recoverFund, ())
    );
    vm.stopPrank();

    uint256 balanceAfter = admin.balance;
    console2.log("balanceAfter", balanceAfter);
    uint256 recoveredFund = balanceAfter - balanceBefore;
    console2.log("recoveredFund", recoveredFund);
    // bridgeTracking.changeProx
  }
}
