// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ILogicValidatorSet, MockLogicValidatorSetV1, MockLogicValidatorSetV2 } from "@ronin/contracts/mocks/utils/version-control/MockLogicValidatorSet.sol";
import { RoninValidatorSetTimedMigrator } from "@ronin/contracts/ronin/validator/migrations/RoninValidatorSetTimedMigrator.sol";
import { MockActor, IConditionalImplementControl, AddressArrayUtils, ConditionalImplementControlTest, TransparentUpgradeableProxyV2 } from "./ConditionalVersionControl.t.sol";

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
   * @notice Tests invalid inputs with duplicated addresses.
   */
  function testFailDuplicatedAddress(uint8 instruction, address dupAddr) public override {
    instruction = instruction % 7; // 0b111
    vm.assume(instruction != 1 && instruction != 2 && instruction != 4); // 0b001, 0b010, 0b100
    address[3] memory inputs = _getTestAddresses();
    for (uint256 i; i < inputs.length; i++) {
      if ((instruction >> i) & 1 == 1) inputs[i] = dupAddr;
    }

    vm.expectRevert(AddressArrayUtils.ErrDuplicated.selector);
    new RoninValidatorSetTimedMigrator(inputs[0], inputs[1], inputs[2]);
  }

  /**
   * @notice Tests invalid inputs with null addresses.
   */
  function testFailNullInputs(uint8 nullIdx) public override {
    nullIdx %= 3;
    address[3] memory inputs = _getTestAddresses();
    delete inputs[nullIdx];

    vm.expectRevert(IConditionalImplementControl.ErrZeroCodeContract.selector);
    new RoninValidatorSetTimedMigrator(inputs[0], inputs[1], inputs[2]);
  }

  /**
   * @notice Tests invalid inputs with non-contract addresses.
   */
  function testFailNonContract(uint8 idx, address nonContract) public override {
    vm.assume(nonContract.code.length == 0);
    idx %= 3;
    address[3] memory inputs = _getTestAddresses();
    delete inputs[idx];

    vm.expectRevert(IConditionalImplementControl.ErrZeroCodeContract.selector);
    new RoninValidatorSetTimedMigrator(inputs[0], inputs[1], inputs[2]);
  }

  /**
   * @notice Checks whether the delegate calls are still to the old implementation contract after upgrading to the
   * contract switcher.
   */
  function testDelegateCallOldImplAfterUsingContractSwitcher() public override {
    testBeforeUpgrading();
    manualUpgradeTo(_switcher);
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
    ILogicValidatorSet(_proxy).wrapUpEpoch();
    assertEq(ILogicValidatorSet(_proxy).version(), ILogicValidatorSet(_newImpl).version());
  }

  /**
   * @notice Checks whether the proxy can receive native token using old implemenation after upgrading to the contract
   * switcher.
   */
  function testReceiveNativeTokenOldImplAfterUsingContractSwitcher(address user, uint256 amount) public override {
    vm.assume(amount > 0);
    vm.deal(user, amount);
    manualUpgradeTo(_switcher);

    vm.expectEmit(_proxy);
    emit Received(ILogicValidatorSet(_oldImpl).version());
    vm.prank(user);
    (bool ok, ) = _proxy.call{ value: amount }("");
    assertEq(ok, true);
    assertEq(amount, _proxy.balance);
  }

  /**
   * @notice Checks whether the proxy can receive native token using new implemenation after upgrading to the contract
   * switcher.
   */
  function testReceiveNativeTokenNewImplAfterUsingContractSwitcher(address user, uint256 amount) public override {
    vm.assume(amount > 0);
    vm.deal(user, amount);
    manualUpgradeTo(_switcher);
    vm.roll(_upgradedAtBlock);
    ILogicValidatorSet(_proxy).wrapUpEpoch();

    vm.expectEmit(_proxy);
    emit Received(ILogicValidatorSet(_newImpl).version());
    vm.prank(user);
    (bool ok, ) = _proxy.call{ value: amount }("");
    assertEq(ok, true);
    assertEq(amount, _proxy.balance);
  }
}
