// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { LibTUint256 } from "./operations/LibTUint256.sol";

type TUint256 is bytes32;

using {
  LibTUint256.add,
  LibTUint256.sub,
  LibTUint256.mul,
  LibTUint256.div,
  LibTUint256.load,
  LibTUint256.store,
  LibTUint256.addAssign,
  LibTUint256.subAssign,
  LibTUint256.preDecrement,
  LibTUint256.postDecrement,
  LibTUint256.preIncrement,
  LibTUint256.postIncrement
} for TUint256 global;
