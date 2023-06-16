// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Vm, Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { TransparentUpgradeableProxyV2, ERC1967Upgrade } from "@ronin/contracts/extensions/TransparentUpgradeableProxyV2.sol";
import { ILogic, MockLogicV1, MockLogicV2 } from "@ronin/contracts/mocks/utils/version-control/MockLogic.sol";
import { MockActor } from "@ronin/contracts/mocks/utils/version-control/MockActor.sol";
import { MockConditionalVersionControl, ConditionalVersionControl } from "@ronin/contracts/mocks/utils/version-control/MockConditionalVersionControl.sol";

contract ConditionalVersionControlTest is Test {
  /**
   * @dev Error thrown when a duplicated element is detected in an array.
   * @param msgSig The function signature that invoke the error.
   */
  error ErrDuplicated(bytes4 msgSig);
  /// @dev Error of set to non-contract.
  error ErrZeroCodeContract(address addr);
  /// @dev Error when contract which delegate to this contract is not compatible with ERC1967
  error ErrDelegateFromUnknownOrigin(address addr);
  /**
   * @dev Error indicating that a function can only be called by the contract itself.
   * @param msgSig The function signature (bytes4) that can only be called by the contract itself.
   */
  error ErrOnlySelfCall(bytes4 msgSig);

  address logicV1;
  address logicV2;

  address payable proxyStorage;
  address payable versionController;
  address admin;
  address alice;
  MockActor bobContract;

  /**
   * @dev Emitted when the implementation is upgraded.
   */
  event Upgraded(address indexed implementation);

  function setUp() public {
    admin = vm.addr(555);
    alice = vm.addr(1);

    logicV1 = address(new MockLogicV1());
    logicV2 = address(new MockLogicV2());

    vm.prank(admin, admin);

    proxyStorage = payable(address(new TransparentUpgradeableProxyV2(logicV1, admin, "")));
    versionController = payable(address(new MockConditionalVersionControl(proxyStorage, logicV1, logicV2)));
    bobContract = new MockActor(proxyStorage);
  }

  function testManualUpgradeToVersionControl() public {
    _testManualUpgrade(versionController);
  }

  function _testManualUpgrade(address implementation) private {
    vm.expectEmit(true, false, false, false);
    emit Upgraded(implementation);
    vm.startPrank(admin, admin);
    TransparentUpgradeableProxyV2(proxyStorage).upgradeTo(implementation);
    assertEq(implementation, TransparentUpgradeableProxyV2(proxyStorage).implementation());
    vm.stopPrank();
  }

  function testFailDupplicateInput0() public {
    vm.expectRevert(abi.encodePacked(ErrDuplicated.selector, bytes4(0)));
    new MockConditionalVersionControl(proxyStorage, proxyStorage, proxyStorage);
  }

  function testFailDupplicateInput1() public {
    vm.expectRevert(abi.encodePacked(ErrDuplicated.selector, bytes4(0)));
    new MockConditionalVersionControl(proxyStorage, logicV1, logicV1);
  }

  function testFailDupplicateInput2() public {
    vm.expectRevert(abi.encodePacked(ErrDuplicated.selector, bytes4(0)));
    new MockConditionalVersionControl(logicV1, proxyStorage, logicV1);
  }

  function testFailNonContractInput0() public {
    vm.expectRevert(abi.encodePacked(ErrZeroCodeContract.selector, alice));
    new MockConditionalVersionControl(alice, logicV1, logicV2);
  }

  function testFailNonContractInput1() public {
    vm.expectRevert(abi.encodePacked(ErrZeroCodeContract.selector, alice));
    new MockConditionalVersionControl(proxyStorage, alice, logicV2);
  }

  function testFailNonContractInput2() public {
    vm.expectRevert(abi.encodePacked(ErrZeroCodeContract.selector, alice));
    new MockConditionalVersionControl(proxyStorage, logicV1, alice);
  }

  function testFailNullInput0() public {
    vm.expectRevert(abi.encodePacked(ErrZeroCodeContract.selector, address(0)));
    new MockConditionalVersionControl(address(0), logicV1, logicV2);
  }

  function testFailNullInput1() public {
    vm.expectRevert(abi.encodePacked(ErrZeroCodeContract.selector, address(0)));
    new MockConditionalVersionControl(proxyStorage, address(0), logicV2);
  }

  function testFailNullInput2() public {
    vm.expectRevert(abi.encodePacked(ErrZeroCodeContract.selector, address(0)));
    new MockConditionalVersionControl(proxyStorage, logicV1, address(0));
  }

  function testGetLogicV1AfterUpgradeToVersionControl() public {
    testManualUpgradeToVersionControl();
    string memory name = ILogic(proxyStorage).name();
    assertEq(name, "LogicV1");
  }

  function testGetLogicV2AfterUpgradeToVersionControl() public {
    testManualUpgradeToVersionControl();
    vm.roll(101);
    string memory name = ILogic(proxyStorage).name();
    assertEq(name, "LogicV2");
  }

  function testSetLogicV2AfterUpgradeToVersionControl() public {
    testManualUpgradeToVersionControl();
    vm.roll(101);
    vm.expectEmit(true, false, false, false);
    emit Upgraded(logicV2);
    ILogic(proxyStorage).set();
    vm.roll(102);
    vm.prank(admin, admin);
    assertEq(logicV2, TransparentUpgradeableProxyV2(proxyStorage).implementation());
    uint256 value = ILogic(proxyStorage).get();
    assertEq(value, 2);
  }

  function testSetLogicV1AfterUpgradeToVersionControl() public {
    testManualUpgradeToVersionControl();
    ILogic(proxyStorage).set();
    uint256 value = ILogic(proxyStorage).get();
    assertEq(value, 1);
  }

  function testVersionControlUseLogicV1WhileConditionNotMet() public {
    vm.roll(10);
    testGetLogicV1AfterUpgradeToVersionControl();
    vm.roll(100);
    testSetLogicV1AfterUpgradeToVersionControl();
  }

  function testFailUnauthorizedEOAForceSwitchToLogicV2() public {
    testManualUpgradeToVersionControl();
    vm.prank(alice, alice);
    vm.expectRevert(abi.encodePacked(ErrOnlySelfCall.selector, ConditionalVersionControl.upgrade.selector));
    MockConditionalVersionControl(proxyStorage).upgrade();
  }

  function testFailUnauthorizedContractForceSwitchToLogicV2() public {
    testManualUpgradeToVersionControl();
    vm.expectRevert(abi.encodePacked(ErrOnlySelfCall.selector, ConditionalVersionControl.upgrade.selector));
    vm.prank(alice, alice);
    MockConditionalVersionControl(payable(address(bobContract))).upgrade();
  }

  function testFailAdminForceSwitchToLogicV2() public {
    testManualUpgradeToVersionControl();
    vm.prank(admin, admin);
    MockConditionalVersionControl(proxyStorage).upgrade();
  }

  function testFailEOACallToVersionControl() public {
    vm.expectRevert(abi.encodePacked(ErrDelegateFromUnknownOrigin.selector, versionController));
    vm.prank(alice, alice);
    ILogic(versionController).set();
  }

  function testFailContractCallToVersionControl() public {
    bobContract = new MockActor(versionController);
    vm.prank(alice, alice);
    vm.expectRevert(abi.encodePacked(ErrDelegateFromUnknownOrigin.selector, versionController));
    ILogic(address(bobContract)).set();
  }

  function testFailEOAStaticCallToVersionControl() public {
    vm.expectRevert(abi.encodePacked(ErrDelegateFromUnknownOrigin.selector, versionController));
    vm.prank(alice, alice);
    ILogic(versionController).get();
  }

  function testFailContractStaticCallCallToVersionControl() public {
    bobContract = new MockActor(versionController);
    vm.prank(alice, alice);
    vm.expectRevert(abi.encodePacked(ErrDelegateFromUnknownOrigin.selector, versionController));
    ILogic(address(bobContract)).get();
  }
}
