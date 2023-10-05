// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./20231003_REP002AndREP003_Base.s.sol";

contract Simulation__20231003_UpgradeREP002AndREP003_RON_NonConditional is
  Simulation__20231003_UpgradeREP002AndREP003_Base
{
  function run() public virtual override trySetUp {
    super.run();

    _upgradeDPoSContracts();

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

  function _upgradeDPoSContracts() internal {
    {
      // upgrade `RoninValidatorSet`
      _validatorSet = RoninValidatorSet(
        _upgradeProxy(ContractKey.RoninValidatorSet, abi.encodeCall(RoninValidatorSet.initializeV2, ()))
      );
      // bump `RoninValidatorSet` to V2, V3
      _validatorSet.initializeV3(loadContractOrDeploy(ContractKey.FastFinalityTracking));
    }

    {
      // upgrade `Staking`
      // bump `Staking` to V2
      _staking = Staking(_upgradeProxy(ContractKey.Staking, abi.encodeCall(Staking.initializeV2, ())));
    }

    {
      // upgrade `SlashIndicator`
      // bump `SlashIndicator` to V2, V3
      _slashIndicator = SlashIndicator(
        _upgradeProxy(
          ContractKey.SlashIndicator,
          abi.encodeCall(
            SlashIndicator.initializeV2,
            (_config.getAddressFromCurrentNetwork(ContractKey.GovernanceAdmin))
          )
        )
      );
      _slashIndicator.initializeV3(loadContractOrDeploy(ContractKey.Profile));
    }

    {
      // upgrade `RoninTrustedOrganization`
      _trustedOrgs = RoninTrustedOrganization(_upgradeProxy(ContractKey.RoninTrustedOrganization, EMPTY_ARGS));
    }

    {
      // upgrade `BridgeTracking`
      // bump `BridgeTracking` to V2
      _bridgeTracking = BridgeTracking(
        _upgradeProxy(ContractKey.BridgeTracking, abi.encodeCall(BridgeTracking.initializeV2, ()))
      );
    }

    {
      // upgrade `StakingVesting`
      // bump `StakingVesting` to V2, V3
      _stakingVesting = StakingVesting(
        _upgradeProxy(ContractKey.StakingVesting, abi.encodeCall(StakingVesting.initializeV2, ()))
      );
      _stakingVesting.initializeV3(50); // 5%
    }

    {
      _fastFinalityTracking = FastFinalityTracking(
        _config.getAddressFromCurrentNetwork(ContractKey.FastFinalityTracking)
      );
    }
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
}
