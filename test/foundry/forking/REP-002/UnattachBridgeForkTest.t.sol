// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../RoninTest.t.sol";

import { RoninValidatorSetTimedMigrator } from "@ronin/contracts/ronin/validator/migrations/RoninValidatorSetTimedMigrator.sol";
import { ICoinbaseExecution } from "@ronin/contracts/interfaces/validator/ICoinbaseExecution.sol";
import { ITimingInfo } from "@ronin/contracts/interfaces/validator/info-fragments/ITimingInfo.sol";
import { MockPrecompile } from "@ronin/contracts/mocks/MockPrecompile.sol";

interface IJailingInfoPrev {
  function checkBridgeRewardDeprecatedAtPeriod(address, uint256) external view returns (bool);
}

contract UnattachBridgeForkTest is RoninTest {
  event Upgraded(address indexed implementation);

  uint256 internal _roninFork;
  address internal _prevImpl;
  address internal _newImpl;
  address internal _versionSwitcher;

  function _createFork() internal virtual override {
    _roninFork = vm.createSelectFork(RONIN_TEST_RPC);
  }

  function _setUp() internal virtual override onWhichFork(_roninFork) {
    address mockPrecompile = deployImmutable(
      type(MockPrecompile).name,
      type(MockPrecompile).creationCode,
      EMPTY_PARAM,
      ZERO_VALUE
    );
    vm.etch(address(0x68), mockPrecompile.code);

    _prevImpl = _getProxyImplementation(RONIN_VALIDATOR_SET_CONTRACT);
    vm.label(_prevImpl, "LogicV1");

    _newImpl = deployImmutable("LogicV2", type(RoninValidatorSet).creationCode, EMPTY_PARAM, ZERO_VALUE);

    _versionSwitcher = deployImmutable(
      type(RoninValidatorSetTimedMigrator).name,
      type(RoninValidatorSetTimedMigrator).creationCode,
      abi.encode(RONIN_VALIDATOR_SET_CONTRACT, _prevImpl, _newImpl),
      ZERO_VALUE
    );
  }

  function test_Fork_UsePrevImplLogic(address a, uint256 b) external onWhichFork(_roninFork) {
    _upgradeToVersionSwitcher();

    // prev logic contains bridge logic `checkBridgeRewardDeprecatedAtPeriod`
    IJailingInfoPrev(address(RONIN_VALIDATOR_SET_CONTRACT)).checkBridgeRewardDeprecatedAtPeriod(a, b);
    RoninValidatorSet(payable(address(RONIN_VALIDATOR_SET_CONTRACT))).currentPeriod();
  }

  function test_Fork_UpgradeToNewImpl_WhenPeriodEnded() external onWhichFork(_roninFork) {
    _upgradeToVersionSwitcher();

    address coinbase = block.coinbase;
    uint256 numberOfBlocksInEpoch = ITimingInfo(address(RONIN_VALIDATOR_SET_CONTRACT)).numberOfBlocksInEpoch();

    uint256 epochEndingBlockNumber = block.number +
      (numberOfBlocksInEpoch - 1) -
      (block.number % numberOfBlocksInEpoch);
    uint256 nextDayTimestamp = block.timestamp + 1 days;

    // fast forward to next day
    vm.warp(nextDayTimestamp);
    vm.roll(epochEndingBlockNumber);

    vm.expectEmit(address(RONIN_VALIDATOR_SET_CONTRACT));
    emit Upgraded(_newImpl);

    vm.prank(coinbase, coinbase);
    ICoinbaseExecution(address(RONIN_VALIDATOR_SET_CONTRACT)).wrapUpEpoch();

    assertEq(_getProxyImplementation(RONIN_VALIDATOR_SET_CONTRACT), _newImpl);
  }

  function _upgradeToVersionSwitcher() internal fromWho(_getProxyAdmin(RONIN_VALIDATOR_SET_CONTRACT)) {
    RONIN_VALIDATOR_SET_CONTRACT.upgradeTo(_versionSwitcher);
  }
}
