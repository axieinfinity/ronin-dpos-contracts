// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

type TPoolId is address;

using { eq as == } for TPoolId global;

function eq(TPoolId a, TPoolId b) pure returns (bool) {
  return TPoolId.unwrap(a) == TPoolId.unwrap(b);
}
