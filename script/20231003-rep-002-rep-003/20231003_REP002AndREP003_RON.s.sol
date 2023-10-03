// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./20231003_REP002AndREP003_Base.s.sol";

contract Simulation__20231003_UpgradeREP002AndREP003_RON is Simulation__20231003_UpgradeREP002AndREP003_Base {
  function run() public virtual override trySetUp {
    super.run();

    {
      // upgrade `RoninValidatorSet` to `RoninValidatorSetTimedMigrator`
      // bump `RoninValidatorSet` to V2, V3
      _validatorSet = new RoninValidatorSetTimedMigratorUpgrade().run();
    }

    {
      // upgrade `Staking` to `NotifiedMigrator`
      // bump `Staking` to V2
      bytes[] memory stakingCallDatas = new bytes[](1);
      stakingCallDatas[0] = abi.encodeCall(Staking.initializeV2, ());
      _staking = Staking(new NotifiedMigratorUpgrade().run(ContractKey.Staking, stakingCallDatas));
    }

    {
      // upgrade `SlashIndicator` to `NotifiedMigrator`
      // bump `SlashIndicator` to V2, V3
      bytes[] memory slashIndicatorDatas = new bytes[](2);
      slashIndicatorDatas[0] = abi.encodeCall(
        SlashIndicator.initializeV2,
        (_config.getAddressFromCurrentNetwork(ContractKey.GovernanceAdmin))
      );
      slashIndicatorDatas[1] = abi.encodeCall(SlashIndicator.initializeV3, (loadContractOrDeploy(ContractKey.Profile)));
      _slashIndicator = SlashIndicator(
        new NotifiedMigratorUpgrade().run(ContractKey.SlashIndicator, slashIndicatorDatas)
      );
    }

    {
      // upgrade `RoninTrustedOrganization`
      bytes[] memory emptyCallDatas;
      _trustedOrgs = RoninTrustedOrganization(
        new NotifiedMigratorUpgrade().run(ContractKey.RoninTrustedOrganization, emptyCallDatas)
      );
    }

    {
      // upgrade `BridgeTracking` to `NotifiedMigrator`
      // bump `BridgeTracking` to V2
      bytes[] memory bridgeTrackingDatas = new bytes[](1);
      bridgeTrackingDatas[0] = abi.encodeCall(BridgeTracking.initializeV2, ());
      _bridgeTracking = BridgeTracking(
        new NotifiedMigratorUpgrade().run(ContractKey.BridgeTracking, bridgeTrackingDatas)
      );
    }

    // // test `RoninGatewayV2` functionality
    // _depositFor("before-upgrade-user");

    // trigger conditional migration
    _fastForwardToNextDay();
    _wrapUpEpoch();

    // // test `RoninValidatorSet` functionality
    // _fastForwardToNextDay();
    // _wrapUpEpoch();

    // // test `RoninGatewayV2` functionality
    // _depositFor("after-upgrade-user");
  }
}
