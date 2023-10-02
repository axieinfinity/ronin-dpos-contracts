// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Staking } from "@ronin/contracts/ronin/staking/Staking.sol";
import { SlashIndicator } from "@ronin/contracts/ronin/slash-indicator/SlashIndicator.sol";
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

  function _injectDependencies() internal virtual override {
    _setDependencyDeployScript(ContractKey.Profile, new ProfileDeploy());
  }

  function run() public virtual trySetUp {
    address mockPrecompile = _deployImmutable(ContractKey.MockPrecompile, EMPTY_ARGS);
    vm.etch(address(0x68), mockPrecompile.code);
    // _wrapUpEpoch();

    _validatorSet = new RoninValidatorSetTimedMigratorUpgrade().run();

    bytes[] memory stakingCallDatas = new bytes[](1);
    stakingCallDatas[0] = abi.encodeCall(Staking.initializeV2, ());
    _staking = Staking(new NotifiedMigratorUpgrade().run(ContractKey.Staking, stakingCallDatas));

    bytes[] memory slashIndicatorDatas = new bytes[](2);
    slashIndicatorDatas[0] = abi.encodeCall(
      SlashIndicator.initializeV2,
      (_config.getAddressFromCurrentNetwork(ContractKey.GovernanceAdmin))
    );
    slashIndicatorDatas[1] = abi.encodeCall(SlashIndicator.initializeV3, (loadContractOrDeploy(ContractKey.Profile)));
    _slashIndicator = SlashIndicator(
      new NotifiedMigratorUpgrade().run(ContractKey.SlashIndicator, slashIndicatorDatas)
    );

    bytes[] memory emptyCallDatas;
    _trustedOrgs = RoninTrustedOrganization(
      new NotifiedMigratorUpgrade().run(ContractKey.RoninTrustedOrganization, emptyCallDatas)
    );

    _fastForwardToNextDay();
    _wrapUpEpoch();
  }

  function _wrapUpEpoch() internal {
    vm.prank(block.coinbase);
    _validatorSet.wrapUpEpoch();
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
