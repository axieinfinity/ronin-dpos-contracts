// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17 <0.9.0;

import { console2 } from "forge-std/console2.sol";
import { StdStyle } from "forge-std/StdStyle.sol";

import "@ronin/contracts/utils/CommonErrors.sol";
import { RoleAccess } from "@ronin/contracts/utils/RoleAccess.sol";
import { IBridgeManager } from "@ronin/contracts/interfaces/bridge/IBridgeManager.sol";
import { IBridgeManagerEvents } from "@ronin/contracts/interfaces/bridge/events/IBridgeManagerEvents.sol";

import { BridgeManager_Unit_Concrete_Test } from "../BridgeManager.t.sol";

contract Update_Unit_Concrete_Test is BridgeManager_Unit_Concrete_Test {
  address private _caller; // the governor to call the update

  function setUp() public virtual override {
    BridgeManager_Unit_Concrete_Test.setUp();

    _caller = _governors[0];
    vm.startPrank({ msgSender: _caller });
  }

  function test_RevertWhen_NotGovernorOfTheChangingBridgeOperator() external {
    address newOperator = _generateBridgeOperatorAddressToUpdate();

    // Make the caller not the governor.
    changePrank({ msgSender: _bridgeOperators[0] });

    // Run the test.
    vm.expectRevert(
      abi.encodeWithSelector(
        ErrUnauthorized.selector,
        IBridgeManager.updateBridgeOperator.selector,
        RoleAccess.GOVERNOR
      )
    );
    _bridgeManager.updateBridgeOperator(newOperator);
  }

  function test_RevertWhen_NewOperatorAddressIsZero() external {
    address newOperator = address(0);

    // Run the test.
    vm.expectRevert(abi.encodeWithSelector(ErrZeroAddress.selector, IBridgeManager.updateBridgeOperator.selector));
    _bridgeManager.updateBridgeOperator(newOperator);
  }

  function test_RevertWhen_NewOperatorIsExistedInCurrentOperatorList() external {
    address newOperator = _bridgeOperators[2];

    // Run the test.
    vm.expectRevert(abi.encodeWithSelector(ErrBridgeOperatorUpdateFailed.selector, newOperator));
    _bridgeManager.updateBridgeOperator(newOperator);
  }

  function test_RevertWhen_NewOperatorIsExistedInCurrentGovernorList() external {
    vm.skip(true);
    address newOperator = _governors[2];

    // Run the test.
    vm.expectRevert(abi.encodeWithSelector(ErrZeroAddress.selector, IBridgeManager.updateBridgeOperator.selector)); // TODO: fix error sig here
    _bridgeManager.updateBridgeOperator(newOperator);
  }

  function test_RevertWhen_NewOperatorIsTheSameWithPreviousOperator() external {
    address prevOperator = unwrapAddress(_bridgeManager.getBridgeOperatorOf(wrapAddress(_caller)));
    address newOperator = prevOperator;

    // Run the test.
    vm.expectRevert(abi.encodeWithSelector(ErrBridgeOperatorAlreadyExisted.selector, prevOperator));
    _bridgeManager.updateBridgeOperator(newOperator);
  }

  function test_UpdateOperators_NewOperatorIsValid() external {
    // Get before test state.
    (
      address[] memory beforeBridgeOperators,
      address[] memory beforeGovernors,
      uint96[] memory beforeVoteWeights
    ) = _getBridgeMembers();

    // Prepare data.
    address prevOperator = unwrapAddress(_bridgeManager.getBridgeOperatorOf(wrapAddress(_caller)));
    address newOperator = _generateBridgeOperatorAddressToUpdate();

    // Run the test

    // Should emit the event
    vm.expectEmit({ emitter: address(_bridgeManager) });
    emit BridgeOperatorUpdated(_caller, prevOperator, newOperator);

    _bridgeManager.updateBridgeOperator(newOperator);

    // Get after test state
    (
      address[] memory afterBridgeOperators,
      address[] memory afterGovernors,
      uint96[] memory afterVoteWeights
    ) = _getBridgeMembers();

    // it should modify the current operators list
    beforeBridgeOperators[0] = newOperator;
    _assertBridgeMembers({
      comparingOperators: beforeBridgeOperators,
      comparingGovernors: beforeGovernors,
      comparingWeights: beforeVoteWeights,
      expectingOperators: afterBridgeOperators,
      expectingGovernors: afterGovernors,
      expectingWeights: afterVoteWeights
    });

    // it should remove the old operator
    assertEq(_bridgeManager.getBridgeOperatorOf(wrapAddress(_caller)), wrapAddress(newOperator));
    assertEq(_bridgeManager.getGovernorsOf(wrapAddress(newOperator)), wrapAddress(_caller));
    assertEq(_bridgeManager.getGovernorsOf(wrapAddress(prevOperator)), wrapAddress(address(0)));
  }
}
