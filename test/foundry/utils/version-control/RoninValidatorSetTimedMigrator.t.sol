// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {
  ILogicValidatorSet,
  MockLogicValidatorSetV1,
  MockLogicValidatorSetV2
} from "@ronin/contracts/mocks/utils/version-control/MockLogicValidatorSet.sol";
import {RoninValidatorSetTimedMigrator} from
  "@ronin/contracts/ronin/validator/migrations/RoninValidatorSetTimedMigrator.sol";
import {
  MockActor,
  IConditionalImplementControl,
  AddressArrayUtils,
  ConditionalImplementControlTest,
  TransparentUpgradeableProxyV2
} from "./ConditionalVersionControl.t.sol";

contract RoninValidatorSetTimedMigratorTest is ConditionalImplementControlTest {
  event Received(string version);

  function _setUp() internal override {
    _proxyAdmin = vm.addr(1);

    _oldImpl = address(new MockLogicValidatorSetV1());
    _newImpl = address(new MockLogicValidatorSetV2());

    _upgradedAtBlock = 100;
    _proxy = payable(address(new TransparentUpgradeableProxyV2(_oldImpl, _proxyAdmin, "")));
    _switcher = payable(address(new RoninValidatorSetTimedMigrator(_proxy, _oldImpl, _newImpl)));
    _contractCaller = new MockActor(_proxy);
  }

  /**
   * @notice Checks before upgrading.
   */
  function testBeforeUpgrading() public override {
    assertEq(ILogicValidatorSet(_proxy).currentPeriod(), 0);
  }

  /**
   * @notice Checks whether the delegate calls are still to the old implementation contract after upgrading to the
   * contract switcher.
   */
  function testDelegateCallOldImplAfterUsingContractSwitcher() public override {
    testBeforeUpgrading();
    manualUpgradeTo(_switcher);
    assertEq(ILogicValidatorSet(_proxy).version(), ILogicValidatorSet(_oldImpl).version());
    ILogicValidatorSet(_proxy).wrapUpEpoch();
    assertEq(ILogicValidatorSet(_proxy).version(), ILogicValidatorSet(_oldImpl).version());
  }

  /**
   * @notice Checks whether the delegate calls are to the new implementation contract after upgrading to the contract
   * switcher and the switch condition is met.
   */
  function testDelegateCallNewImplAfterUsingContractSwitcher() public override {
    testDelegateCallOldImplAfterUsingContractSwitcher();
    vm.roll(_upgradedAtBlock);
    assertEq(ILogicValidatorSet(_proxy).version(), ILogicValidatorSet(_oldImpl).version());
    ILogicValidatorSet(_proxy).wrapUpEpoch();
    assertEq(ILogicValidatorSet(_proxy).version(), ILogicValidatorSet(_newImpl).version());
  }

  /**
   * @notice Checks whether the proxy can receive native token using old implemenation after upgrading to the contract
   * switcher.
   */
  function testReceiveNativeTokenOldImplAfterUsingContractSwitcher(address user, uint256 amount) public override {
    vm.assume(amount > 0 && user != _proxyAdmin);
    vm.deal(user, amount);
    manualUpgradeTo(_switcher);

    vm.expectEmit(_proxy);
    emit Received(ILogicValidatorSet(_oldImpl).version());
    vm.prank(user);
    (bool ok,) = _proxy.call{value: amount}("");
    assertEq(ok, true);
    assertEq(amount, _proxy.balance);
  }

  /**
   * @notice Checks whether the proxy can receive native token using new implemenation after upgrading to the contract
   * switcher.
   */
  function testReceiveNativeTokenNewImplAfterUsingContractSwitcher(address user, uint256 amount) public override {
    vm.assume(amount > 0 && user != _proxyAdmin);
    vm.deal(user, amount);
    manualUpgradeTo(_switcher);
    vm.roll(_upgradedAtBlock);

    emit Received(ILogicValidatorSet(_oldImpl).version());
    ILogicValidatorSet(_proxy).wrapUpEpoch();

    vm.expectEmit(_proxy);
    emit Received(ILogicValidatorSet(_newImpl).version());
    vm.prank(user);
    (bool ok,) = _proxy.call{value: amount}("");
    assertEq(ok, true);
    assertEq(amount, _proxy.balance);
  }

  /**
   * @dev Creates a new conditional implement control for testing purposes.
   */
  function _createConditionalImplementControl(address[3] memory inputs) internal override returns (address) {
    return address(new RoninValidatorSetTimedMigrator(inputs[0], inputs[1], inputs[2]));
  }
}
