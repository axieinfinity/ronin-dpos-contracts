// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { TUint256Slot } from "../../types/Types.sol";

contract MockTUint256Slot {
  TUint256Slot private constant CUSTOM_SLOT_UINT256 =
    TUint256Slot.wrap(keccak256(abi.encode(type(MockTUint256Slot).name)));

  uint256 private _primitiveUint256;

  function subPrimitive(uint256 val) external view returns (uint256 res) {
    res = _primitiveUint256 - val;
  }

  function subCustomSlot(uint256 val) external view returns (uint256 res) {
    res = CUSTOM_SLOT_UINT256.sub(val);
  }

  function divCustomSlot(uint256 val) external view returns (uint256 res) {
    res = CUSTOM_SLOT_UINT256.div(val);
  }

  function divPrimitive(uint256 val) external view returns (uint256 res) {
    res = _primitiveUint256 / val;
  }

  function mulCustomSlot(uint256 val) external view returns (uint256 res) {
    res = CUSTOM_SLOT_UINT256.mul(val);
  }

  function mulPrimitive(uint256 val) external view returns (uint256 res) {
    res = _primitiveUint256 * val;
  }

  function addPrimitive(uint256 val) external view returns (uint256 res) {
    res = _primitiveUint256 + val;
  }

  function addCustomSlot(uint256 val) external view returns (uint256 res) {
    res = CUSTOM_SLOT_UINT256.add(val);
  }

  function preIncrementPrimitive() external returns (uint256 res) {
    res = ++_primitiveUint256;
  }

  function preIncrementCustomSlot() external returns (uint256 res) {
    res = CUSTOM_SLOT_UINT256.preIncrement();
  }

  function postIncrementPrimitive() external returns (uint256 res) {
    res = _primitiveUint256++;
  }

  function postIncrementCustomSlot() external returns (uint256 res) {
    res = CUSTOM_SLOT_UINT256.postIncrement();
  }

  function preDecrementPrimitive() external returns (uint256 res) {
    res = --_primitiveUint256;
  }

  function preDecrementCustomSlot() external returns (uint256 res) {
    res = CUSTOM_SLOT_UINT256.preDecrement();
  }

  function postDecrementPrimitive() external returns (uint256 res) {
    res = _primitiveUint256--;
  }

  function postDecrementCustomSlot() external returns (uint256 res) {
    res = CUSTOM_SLOT_UINT256.postDecrement();
  }

  function setCustomSlot(uint256 val) external returns (uint256 stored) {
    CUSTOM_SLOT_UINT256.store(val);
    stored = CUSTOM_SLOT_UINT256.load();
  }

  function setPrimitive(uint256 val) external returns (uint256 stored) {
    _primitiveUint256 = val;
    stored = _primitiveUint256;
  }

  function subAssignCustomSlot(uint256 val) external returns (uint256 stored) {
    stored = CUSTOM_SLOT_UINT256.subAssign(val);
  }

  function subAssignPrimitive(uint256 val) external returns (uint256 stored) {
    stored = _primitiveUint256 -= val;
  }

  function addAssignCustomSlot(uint256 val) external returns (uint256 stored) {
    stored = CUSTOM_SLOT_UINT256.addAssign(val);
  }

  function addAssignPrimitive(uint256 val) external returns (uint256 stored) {
    stored = _primitiveUint256 += val;
  }

  function getPrimitive() external view returns (uint256) {
    return _primitiveUint256;
  }

  function getCustomSlot() external view returns (uint256) {
    return CUSTOM_SLOT_UINT256.load();
  }
}
