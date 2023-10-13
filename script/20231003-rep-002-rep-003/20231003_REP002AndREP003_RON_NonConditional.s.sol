// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StdStyle } from "forge-std/StdStyle.sol";

import "./20231003_REP002AndREP003_Base.s.sol";

contract Simulation__20231003_UpgradeREP002AndREP003_RON_NonConditional is
  Simulation__20231003_UpgradeREP002AndREP003_Base
{
  function run() public virtual override trySetUp {
    super.run();

    _upgradeDPoSContracts();

    // // test `RoninGatewayV3` functionality
    // _depositFor("before-upgrade-user");

    // trigger conditional migration
    _fastForwardToNextDay();
    _wrapUpEpoch();

    // // test `RoninValidatorSet` functionality
    // _fastForwardToNextDay();
    // _wrapUpEpoch();

    // // test `RoninGatewayV3` functionality
    // _depositFor("after-upgrade-user");
  }

  function _upgradeDPoSContracts() internal {
    console2.log("> ", StdStyle.blue("_upgradeDPoSContracts"), "...");

    {
      // upgrade `RoninValidatorSet`
      _upgradeProxy(ContractKey.RoninValidatorSet, abi.encodeCall(RoninValidatorSet.initializeV2, ()));
      // bump `RoninValidatorSet` to V2, V3
      _validatorSet.initializeV3(loadContractOrDeploy(ContractKey.FastFinalityTracking));
    }

    {
      // upgrade `Staking`
      // bump `Staking` to V2
      _upgradeProxy(ContractKey.Staking, abi.encodeCall(Staking.initializeV2, ()));
    }

    {
      // upgrade `SlashIndicator`
      // bump `SlashIndicator` to V2, V3

      _upgradeProxy(
        ContractKey.SlashIndicator,
        abi.encodeCall(SlashIndicator.initializeV2, (address(_roninGovernanceAdmin)))
      );
      _slashIndicator.initializeV3(loadContractOrDeploy(ContractKey.Profile));
    }

    {
      // upgrade `RoninTrustedOrganization`
      _upgradeProxy(ContractKey.RoninTrustedOrganization, EMPTY_ARGS);
    }

    {
      // upgrade `BridgeTracking`
      // bump `BridgeTracking` to V2
      _upgradeProxy(ContractKey.BridgeTracking, abi.encodeCall(BridgeTracking.initializeV2, ()));
    }

    {
      // upgrade `StakingVesting`
      // bump `StakingVesting` to V2, V3
      _upgradeProxy(ContractKey.StakingVesting, abi.encodeCall(StakingVesting.initializeV2, ()));
      _stakingVesting.initializeV3(50); // 5%
    }
  }


}
