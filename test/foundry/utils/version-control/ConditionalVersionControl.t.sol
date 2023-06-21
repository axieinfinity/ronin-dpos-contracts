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
    versionController = payable(address(new MockConditionalImplementControl(proxyStorage, logicV1, logicV2)));
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
    vm.expectRevert(abi.encodePacked(AddressArrayUtils.ErrDuplicated.selector, bytes4(0)));
    new MockConditionalImplementControl(proxyStorage, proxyStorage, proxyStorage);
  }

  function testFailDupplicateInput1() public {
    vm.expectRevert(abi.encodePacked(AddressArrayUtils.ErrDuplicated.selector, bytes4(0)));
    new MockConditionalImplementControl(proxyStorage, logicV1, logicV1);
  }

  function testFailDupplicateInput2() public {
    vm.expectRevert(abi.encodePacked(AddressArrayUtils.ErrDuplicated.selector, bytes4(0)));
    new MockConditionalImplementControl(logicV1, proxyStorage, logicV1);
  }

  function testFailNonContractInput0() public {
    vm.expectRevert(abi.encodePacked(IConditionalImplementControl.ErrZeroCodeContract.selector, alice));
    new MockConditionalImplementControl(alice, logicV1, logicV2);
  }

  function testFailNonContractInput1() public {
    vm.expectRevert(abi.encodePacked(IConditionalImplementControl.ErrZeroCodeContract.selector, alice));
    new MockConditionalImplementControl(proxyStorage, alice, logicV2);
  }

  function testFailNonContractInput2() public {
    vm.expectRevert(abi.encodePacked(IConditionalImplementControl.ErrZeroCodeContract.selector, alice));
    new MockConditionalImplementControl(proxyStorage, logicV1, alice);
  }

  function testFailNullInput0() public {
    vm.expectRevert(abi.encodePacked(IConditionalImplementControl.ErrZeroCodeContract.selector, address(0)));
    new MockConditionalImplementControl(address(0), logicV1, logicV2);
  }

  function testFailNullInput1() public {
    vm.expectRevert(abi.encodePacked(IConditionalImplementControl.ErrZeroCodeContract.selector, address(0)));
    new MockConditionalImplementControl(proxyStorage, address(0), logicV2);
  }

  function testFailNullInput2() public {
    vm.expectRevert(abi.encodePacked(IConditionalImplementControl.ErrZeroCodeContract.selector, address(0)));
    new MockConditionalImplementControl(proxyStorage, logicV1, address(0));
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
    vm.expectRevert(
      abi.encodePacked(
        ErrOnlySelfCall.selector,
        ConditionalImplementControl.selfMigrate.selector
      )
    );
    MockConditionalImplementControl(proxyStorage).selfMigrate();
  }

  function testFailUnauthorizedContractForceSwitchToLogicV2() public {
    testManualUpgradeToVersionControl();
    vm.expectRevert(
      abi.encodePacked(
        ErrOnlySelfCall.selector,
        ConditionalImplementControl.selfMigrate.selector
      )
    );
    vm.prank(alice, alice);
    MockConditionalImplementControl(payable(address(bobContract))).selfMigrate();
  }

  function testFailAdminForceSwitchToLogicV2() public {
    testManualUpgradeToVersionControl();
    vm.prank(admin, admin);
    MockConditionalImplementControl(proxyStorage).selfMigrate();
  }

  function testFailEOACallToVersionControl() public {
    vm.expectRevert(
      abi.encodePacked(IConditionalImplementControl.ErrDelegateFromUnknownOrigin.selector, versionController)
    );
    vm.prank(alice, alice);
    ILogic(versionController).set();
  }

  function testFailContractCallToVersionControl() public {
    bobContract = new MockActor(versionController);
    vm.prank(alice, alice);
    vm.expectRevert(
      abi.encodePacked(IConditionalImplementControl.ErrDelegateFromUnknownOrigin.selector, versionController)
    );
    ILogic(address(bobContract)).set();
  }

  function testFailEOAStaticCallToVersionControl() public {
    vm.expectRevert(
      abi.encodePacked(IConditionalImplementControl.ErrDelegateFromUnknownOrigin.selector, versionController)
    );
    vm.prank(alice, alice);
    ILogic(versionController).get();
  }

  function testFailContractStaticCallCallToVersionControl() public {
    bobContract = new MockActor(versionController);
    vm.prank(alice, alice);
    vm.expectRevert(
      abi.encodePacked(IConditionalImplementControl.ErrDelegateFromUnknownOrigin.selector, versionController)
    );
    ILogic(address(bobContract)).get();
  }
}
