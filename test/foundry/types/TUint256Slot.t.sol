// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { stdError, Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { MockTUint256Slot } from "@ronin/contracts/mocks/types/MockTUint256Slot.sol";

contract TUint256SlotTest is Test {
  MockTUint256Slot internal mock;

  function setUp() external {
    _setUp();
    _label();
  }

  function test_Store(uint256 val) external {
    uint256 a = mock.setCustomSlot(val);
    uint256 b = mock.setPrimitive(val);

    assertEq(a, b);
  }

  function test_Load(uint256 val) external {
    mock.setCustomSlot(val);
    mock.setPrimitive(val);

    assertEq(mock.getCustomSlot(), val);
    assertEq(mock.getPrimitive(), val);
  }

  function test_Add(uint128 initVal, uint96 val) external {
    mock.setCustomSlot(initVal);
    mock.setPrimitive(initVal);

    uint256 expected = uint256(initVal) + val;

    uint256 actualA = mock.addPrimitive(val);
    uint256 actualB = mock.addCustomSlot(val);

    assertEq(actualA, expected);
    assertEq(actualB, expected);
  }

  function test_Sub(uint256 initVal, uint256 val) external {
    vm.assume(initVal > val);
    mock.setCustomSlot(initVal);
    mock.setPrimitive(initVal);

    uint256 expected = initVal - val;
    uint256 actualA = mock.subPrimitive(val);
    uint256 actualB = mock.subCustomSlot(val);

    assertEq(actualA, expected);
    assertEq(actualB, expected);
  }

  function test_Mul(uint128 initVal, uint96 val) external {
    mock.setCustomSlot(initVal);
    mock.setPrimitive(initVal);

    uint256 expected = uint256(initVal) * val;
    uint256 actualA = mock.mulPrimitive(val);
    uint256 actualB = mock.mulCustomSlot(val);

    assertEq(actualA, expected);
    assertEq(actualB, expected);
  }

  function test_Div(uint256 initVal, uint256 val) external {
    vm.assume(val != 0);
    mock.setCustomSlot(initVal);
    mock.setPrimitive(initVal);

    uint256 expected = uint256(initVal) / val;
    uint256 actualA = mock.divPrimitive(val);
    uint256 actualB = mock.divCustomSlot(val);

    assertEq(actualA, expected);
    assertEq(actualB, expected);
  }

  function test_MultiplyByZero_Mul(uint256 initVal, uint256 val) external {
    uint256 actual = mock.mulCustomSlot(val);
    assertEq(actual, 0);

    mock.setCustomSlot(initVal);
    actual = mock.mulCustomSlot(0);
    assertEq(actual, 0);
  }

  function test_Fail_Overflow_Mul(uint256 a, uint256 b) external {
    vm.assume(a != 0);
    uint256 c;
    assembly {
      c := mul(a, b)
    }
    vm.assume(c / a != b);

    mock.setCustomSlot(a);
    vm.expectRevert(stdError.arithmeticError);
    uint256 actual = mock.mulCustomSlot(b);

    mock.setCustomSlot(b);
    vm.expectRevert(stdError.arithmeticError);
    actual = mock.mulCustomSlot(a);
  }

  function test_Fail_DivideByZero_Div(uint256 initVal) external {
    mock.setCustomSlot(initVal);
    vm.expectRevert(stdError.divisionError);
    mock.divCustomSlot(0);
  }

  function test_AddAssign(uint128 initVal, uint96 val) external {
    mock.setCustomSlot(initVal);
    mock.setPrimitive(initVal);

    uint256 expected = uint256(initVal) + val;

    uint256 actualA = mock.addAssignPrimitive(val);
    uint256 actualB = mock.addAssignCustomSlot(val);

    assertEq(actualA, expected);
    assertEq(actualB, expected);
    assertEq(mock.getCustomSlot(), expected);
    assertEq(mock.getPrimitive(), expected);
  }

  function test_SubAssign(uint256 initVal, uint256 val) external {
    vm.assume(initVal > val);
    mock.setCustomSlot(initVal);
    mock.setPrimitive(initVal);

    uint256 expected = initVal - val;
    uint256 actualA = mock.subAssignPrimitive(val);
    uint256 actualB = mock.subAssignCustomSlot(val);

    assertEq(actualA, expected);
    assertEq(actualB, expected);
    assertEq(mock.getCustomSlot(), expected);
    assertEq(mock.getPrimitive(), expected);
  }

  function test_PostIncrement(uint128 initVal) external {
    mock.setCustomSlot(initVal);
    mock.setPrimitive(initVal);

    uint256 expected = mock.postIncrementPrimitive();
    uint256 actual = mock.postIncrementCustomSlot();
    assertEq(uint256(initVal) + 1, mock.getCustomSlot());
    assertEq(expected, actual);
  }

  function test_PreIncrement(uint128 initVal) external {
    mock.setCustomSlot(initVal);
    mock.setPrimitive(initVal);

    uint256 expected = mock.preIncrementPrimitive();
    uint256 actual = mock.preIncrementCustomSlot();
    assertEq(uint256(initVal) + 1, mock.getCustomSlot());
    assertEq(expected, actual);
  }

  function test_PostDecrement(uint128 initVal) external {
    vm.assume(initVal != 0);
    mock.setCustomSlot(initVal);
    mock.setPrimitive(initVal);

    uint256 expected = mock.postDecrementPrimitive();
    uint256 actual = mock.postDecrementCustomSlot();
    assertEq(uint256(initVal) - 1, mock.getCustomSlot());
    assertEq(expected, actual);
  }

  function test_PreDecrement(uint128 initVal) external {
    vm.assume(initVal != 0);
    mock.setCustomSlot(initVal);
    mock.setPrimitive(initVal);

    uint256 expected = mock.preDecrementPrimitive();
    uint256 actual = mock.preDecrementCustomSlot();
    assertEq(uint256(initVal) - 1, mock.getCustomSlot());
    assertEq(expected, actual);
  }

  function test_Fail_Overflow_Add(uint256 val) external {
    vm.assume(val != 0);
    mock.setCustomSlot(type(uint256).max);
    vm.expectRevert(stdError.arithmeticError);
    uint256 actual = mock.addCustomSlot(val);
    console.log(actual);
  }

  function test_Fail_Underflow_Sub(uint256 val) external {
    vm.assume(val != 0);
    vm.expectRevert(stdError.arithmeticError);
    uint256 actual = mock.subCustomSlot(val);
    console.log(actual);
  }

  function _setUp() internal virtual {
    mock = new MockTUint256Slot();
  }

  function _label() internal virtual {
    vm.label(address(mock), "MOCK");
  }
}
