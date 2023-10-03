// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Staking } from "@ronin/contracts/ronin/staking/Staking.sol";
import { SlashIndicator } from "@ronin/contracts/ronin/slash-indicator/SlashIndicator.sol";
import { BridgeTracking } from "@ronin/contracts/ronin/gateway/BridgeTracking.sol";
import { RoninTrustedOrganization } from "@ronin/contracts/multi-chains/RoninTrustedOrganization.sol";
import { console2, BaseDeploy, ContractKey } from "../BaseDeploy.s.sol";
import { MockPrecompile } from "@ronin/contracts/mocks/MockPrecompile.sol";
import { NotifiedMigratorUpgrade } from "./contracts/NotifiedMigratorUpgrade.s.sol";
import { RoninValidatorSet, RoninValidatorSetTimedMigratorUpgrade } from "./contracts/RoninValidatorSetTimedMigratorUpgrade.s.sol";
import { ProfileDeploy } from "./contracts/ProfileDeploy.s.sol";

contract Simulation__20231003_UpgradeREP002AndREP003_RON is BaseDeploy {
  Staking internal _staking;
  SlashIndicator internal _slashIndicator;
  RoninValidatorSet internal _validatorSet;
  RoninTrustedOrganization internal _trustedOrgs;
  BridgeTracking internal _bridgeTracking;

  function _injectDependencies() internal virtual override {
    _setDependencyDeployScript(ContractKey.Profile, new ProfileDeploy());
  }

  function run() public virtual trySetUp {
    address mockPrecompile = _deployImmutable(ContractKey.MockPrecompile, EMPTY_ARGS);
    vm.etch(address(0x68), mockPrecompile.code);
    // _wrapUpEpoch();

    // _validatorSet = new RoninValidatorSetTimedMigratorUpgrade().run();
    bytes[] memory validatorSetCallDatas = new bytes[](1);
    validatorSetCallDatas[0] = abi.encodeCall(RoninValidatorSet.initializeV2, ());
    _upgradeProxy(ContractKey.RoninValidatorSet, validatorSetCallDatas[0]);
    _validatorSet = RoninValidatorSet(loadContractOrDeploy(ContractKey.RoninValidatorSet));
    _validatorSet.initializeV3(loadContractOrDeploy(ContractKey.FastFinalityTracking));

    bytes[] memory stakingCallDatas = new bytes[](1);
    stakingCallDatas[0] = abi.encodeCall(Staking.initializeV2, ());
    // _staking = Staking(new NotifiedMigratorUpgrade().run(ContractKey.Staking, stakingCallDatas));
    _upgradeProxy(ContractKey.Staking, stakingCallDatas[0]);

    bytes[] memory slashIndicatorDatas = new bytes[](2);
    slashIndicatorDatas[0] = abi.encodeCall(
      SlashIndicator.initializeV2,
      (_config.getAddressFromCurrentNetwork(ContractKey.GovernanceAdmin))
    );
    slashIndicatorDatas[1] = abi.encodeCall(SlashIndicator.initializeV3, (loadContractOrDeploy(ContractKey.Profile)));
    // _slashIndicator = SlashIndicator(
    //   new NotifiedMigratorUpgrade().run(ContractKey.SlashIndicator, slashIndicatorDatas)
    // );
    _upgradeProxy(ContractKey.SlashIndicator, slashIndicatorDatas[0]);
    _slashIndicator = SlashIndicator(loadContractOrDeploy(ContractKey.SlashIndicator));
    _slashIndicator.initializeV3(loadContractOrDeploy(ContractKey.Profile));

    bytes[] memory emptyCallDatas = new bytes[](1);
    // _trustedOrgs = RoninTrustedOrganization(
    //   new NotifiedMigratorUpgrade().run(ContractKey.RoninTrustedOrganization, emptyCallDatas)
    // );
    _upgradeProxy(ContractKey.RoninTrustedOrganization, emptyCallDatas[0]);

    bytes[] memory bridgeTrackingCallDatas = new bytes[](1);
    bridgeTrackingCallDatas[0] = abi.encodeCall(BridgeTracking.initializeV2, ());
    // _bridgeTracking = BridgeTracking(
    //   new NotifiedMigratorUpgrade().run(ContractKey.BridgeTracking, bridgeTrackingCallDatas)
    // );
    _upgradeProxy(ContractKey.BridgeTracking, bridgeTrackingCallDatas[0]);

    _fastForwardToNextEpoch();
    _wrapUpEpoch();

    _fastForwardToNextDay();
    _wrapUpEpoch();
  }

  function _wrapUpEpoch() internal {
    vm.prank(block.coinbase);
    _validatorSet.wrapUpEpoch();
  }

  function _fastForwardToNextEpoch() internal {
    vm.warp(block.timestamp + 3 seconds);
    vm.roll(block.number + 1);

    uint256 numberOfBlocksInEpoch = _validatorSet.numberOfBlocksInEpoch();

    uint256 epochEndingBlockNumber = block.number +
      (numberOfBlocksInEpoch - 1) -
      (block.number % numberOfBlocksInEpoch);

    // fast forward to next day
    vm.roll(epochEndingBlockNumber);
  }

  function _fastForwardToNextDay() internal {
    vm.warp(block.timestamp + 3 seconds);
    vm.roll(block.number + 1);

    uint256 numberOfBlocksInEpoch = _validatorSet.numberOfBlocksInEpoch();

    uint256 epochEndingBlockNumber = block.number +
      (numberOfBlocksInEpoch - 1) -
      (block.number % numberOfBlocksInEpoch);
    uint256 nextDayTimestamp = block.timestamp + 1 days;

    // fast forward to next day
    vm.warp(nextDayTimestamp);
    vm.roll(epochEndingBlockNumber);
  }
}
