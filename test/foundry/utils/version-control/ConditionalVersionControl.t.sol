// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Vm, Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { TransparentUpgradeableProxyV2, ERC1967Upgrade } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { ILogic, MockLogicV1, MockLogicV2 } from "@ronin/contracts/mocks/utils/version-control/MockLogic.sol";
import { IConditionalImplementControl } from "@ronin/contracts/interfaces/version-control/IConditionalImplementControl.sol";
import { AddressArrayUtils } from "@ronin/contracts/libraries/AddressArrayUtils.sol";
import { ErrOnlySelfCall } from "@ronin/contracts/utils/CommonErrors.sol";
import { MockActor } from "@ronin/contracts/mocks/utils/version-control/MockActor.sol";
import { MockConditionalImplementControl, ConditionalImplementControl } from "@ronin/contracts/mocks/utils/version-control/MockConditionalImplementControl.sol";

contract ConditionalImplementControlTest is Test {
  /**
   * @dev Emitted when the implementation is upgraded.
   */
  event Upgraded(address indexed implementation);
  event Received(uint256 version);

  uint256 internal _upgradedAtBlock;
  address internal _oldImpl;
  address internal _newImpl;

  address payable internal _proxy;
  address payable internal _switcher;

  address internal _proxyAdmin;
  address internal _alice;
  MockActor internal _contractCaller;

  function setUp() public virtual {
    _proxyAdmin = vm.addr(1);
    _alice = vm.addr(2);

    _oldImpl = address(new MockLogicV1());
    _newImpl = address(new MockLogicV2());

    _upgradedAtBlock = block.number + 0xfffffff;
    _proxy = payable(address(new TransparentUpgradeableProxyV2(_oldImpl, _proxyAdmin, "")));
    _switcher = payable(address(new MockConditionalImplementControl(_proxy, _oldImpl, _newImpl, _upgradedAtBlock)));
    _contractCaller = new MockActor(_proxy);
  }

  /**
   * @notice Checks before upgrading.
   */
  function testBeforeUpgrading() public virtual {
    assertEq(ILogic(_proxy).get(), 0);
  }

  /**
   * @notice Checks whether we can upgrade the proxy without any problem.
   */
  function testUpgradeToSwitcher() public virtual {
    manualUpgradeTo(_switcher);
    vm.prank(_proxyAdmin);
    assertEq(_switcher, TransparentUpgradeableProxyV2(_proxy).implementation());
  }

  /**
   * @notice Tests invalid inputs with duplicated addresses.
   */
  function testFailDuplicatedAddress(uint8 instruction, address dupAddr) public virtual {
    instruction = instruction % 7; // 0b111
    vm.assume(instruction != 1 && instruction != 2 && instruction != 4); // 0b001, 0b010, 0b100
    address[3] memory inputs = _getTestAddresses();
    for (uint256 i; i < inputs.length; i++) {
      if ((instruction >> i) & 1 == 1) inputs[i] = dupAddr;
    }

    vm.expectRevert(AddressArrayUtils.ErrDuplicated.selector);
    new MockConditionalImplementControl(inputs[0], inputs[1], inputs[2], _upgradedAtBlock);
  }

  /**
   * @notice Tests invalid inputs with null addresses.
   */
  function testFailNullInputs(uint8 nullIdx) public virtual {
    nullIdx %= 3;
    address[3] memory inputs = _getTestAddresses();
    delete inputs[nullIdx];

    vm.expectRevert(IConditionalImplementControl.ErrZeroCodeContract.selector);
    new MockConditionalImplementControl(inputs[0], inputs[1], inputs[2], _upgradedAtBlock);
  }

  /**
   * @notice Tests invalid inputs with non-contract addresses.
   */
  function testFailNonContract(uint8 idx, address nonContract) public virtual {
    vm.assume(nonContract.code.length == 0);
    idx %= 3;
    address[3] memory inputs = _getTestAddresses();
    delete inputs[idx];

    vm.expectRevert(IConditionalImplementControl.ErrZeroCodeContract.selector);
    new MockConditionalImplementControl(inputs[0], inputs[1], inputs[2], _upgradedAtBlock);
  }

  /**
   * @notice Checks whether the delegate calls are still to the old implementation contract after upgrading to the
   * contract switcher.
   */
  function testDelegateCallOldImplAfterUsingContractSwitcher() public virtual {
    testBeforeUpgrading();
    manualUpgradeTo(_switcher);
    ILogic(_proxy).set();
    assertEq(ILogic(_proxy).get(), ILogic(_oldImpl).magicNumber());
    assertEq(ILogic(_proxy).name(), ILogic(_oldImpl).name());
  }

  /**
   * @notice Checks whether the delegate calls are to the new implementation contract after upgrading to the contract
   * switcher and the switch condition is met.
   */
  function testDelegateCallNewImplAfterUsingContractSwitcher() public virtual {
    testDelegateCallOldImplAfterUsingContractSwitcher();
    vm.roll(_upgradedAtBlock);
    ILogic(_proxy).set();
    assertEq(ILogic(_proxy).get(), ILogic(_newImpl).magicNumber());
    assertEq(ILogic(_proxy).name(), ILogic(_newImpl).name());
  }

  /**
   * @notice Checks receive native token functionality implemented in logicV1 when using contract switcher.
   */
  function testSendNativeLogicV1AfterUpgradeToVersionControl() public {
    manualUpgradeTo(_switcher);
    vm.expectEmit(true, false, false, false);
    emit Received(1);
    vm.deal(_alice, 10 ether);
    vm.prank(_alice, _alice);
    (bool ok, ) = _proxy.call{ value: 1 ether }("");
    assertEq(ok, true);
    assertEq(1 ether, _proxy.balance);
  }

  /**
   * @notice Checks receive native token functionality implemented in logicV2 when using contract switcher.
   */
  function testSendNativeLogicV2AfterUpgradeToVersionControl() public {
    manualUpgradeTo(_switcher);
    vm.roll(101);
    vm.expectEmit(true, false, false, false);
    emit Received(2);
    vm.deal(_alice, 10 ether);
    vm.prank(_alice, _alice);
    (bool ok, ) = _proxy.call{ value: 1 ether }("");
    assertEq(ok, true);
    assertEq(1 ether, _proxy.balance);
  }

  /**
   * @notice Tests unauthorized EOA calls to the method `selfUpgrade`.
   */
  function testFailUnauthorizedEOACallSelfUpgrade(address user) public virtual {
    manualUpgradeTo(_switcher);
    vm.prank(user);
    vm.expectRevert(abi.encodePacked(ErrOnlySelfCall.selector, ConditionalImplementControl.selfUpgrade.selector));
    MockConditionalImplementControl(_proxy).selfUpgrade();
  }

  /**
   * @notice Tests unauthorized contract calls to the method `selfUpgrade`.
   */
  function testFailUnauthorizedContractCallSelfUpgrade() public virtual {
    manualUpgradeTo(_switcher);
    vm.expectRevert(abi.encodePacked(ErrOnlySelfCall.selector, ConditionalImplementControl.selfUpgrade.selector));
    MockConditionalImplementControl(payable(address(_contractCaller))).selfUpgrade();
  }

  /**
   * @notice Tests fail calls to the method `selfUpgrade` event from admin.
   */
  function testFailAdminCallSelfUpgrade() public virtual {
    manualUpgradeTo(_switcher);
    vm.prank(_proxyAdmin);
    MockConditionalImplementControl(_proxy).selfUpgrade();
  }

  /**
   * @notice Tests unauthorized EOA calls to the non-view methods.
   */
  function testFailEOACallNonViewMethodToContractSwitcher(address user) public virtual {
    vm.expectRevert(abi.encodePacked(IConditionalImplementControl.ErrDelegateFromUnknownOrigin.selector, _switcher));
    vm.prank(user);
    ILogic(_switcher).set();
  }

  /**
   * @notice Tests unauthorized EOA calls to the view methods.
   */
  function testFailEOACallViewMethodToContractSwitcher(address user) public virtual {
    vm.expectRevert(abi.encodePacked(IConditionalImplementControl.ErrDelegateFromUnknownOrigin.selector, _switcher));
    vm.prank(user);
    ILogic(_switcher).get();
  }

  /**
   * @notice Tests unauthorized contract calls to the non-view methods.
   */
  function testFailContractCallNonViewMethodToContractSwitcher() public virtual {
    _contractCaller = new MockActor(_switcher);
    vm.expectRevert(abi.encodePacked(IConditionalImplementControl.ErrDelegateFromUnknownOrigin.selector, _switcher));
    ILogic(address(_contractCaller)).set();
  }

  /**
   * @notice Tests unauthorized contract calls to the view methods.
   */
  function testFailContractCallViewMethodToContractSwitcher() public virtual {
    _contractCaller = new MockActor(_switcher);
    vm.expectRevert(abi.encodePacked(IConditionalImplementControl.ErrDelegateFromUnknownOrigin.selector, _switcher));
    ILogic(address(_contractCaller)).get();
  }

  /**
   * @dev Upgrades the proxy to address `impl`.
   */
  function manualUpgradeTo(address impl) public virtual {
    vm.prank(_proxyAdmin);
    TransparentUpgradeableProxyV2(_proxy).upgradeTo(impl);
  }

  /**
   * @dev Returns the test addresses.
   */
  function _getTestAddresses() internal view returns (address[3] memory inputs) {
    return [_proxy, _oldImpl, _newImpl];
  }
}
