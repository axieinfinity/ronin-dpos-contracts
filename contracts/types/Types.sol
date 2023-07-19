// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { LibTUint256Slot } from "./operations/LibTUint256Slot.sol";

type TUint256Slot is bytes32;

using {
  LibTUint256Slot.add,
  LibTUint256Slot.sub,
  LibTUint256Slot.mul,
  LibTUint256Slot.div,
  LibTUint256Slot.load,
  LibTUint256Slot.store,
  LibTUint256Slot.addAssign,
  LibTUint256Slot.subAssign,
  LibTUint256Slot.preDecrement,
  LibTUint256Slot.postDecrement,
  LibTUint256Slot.preIncrement,
  LibTUint256Slot.postIncrement
} for TUint256Slot global;
