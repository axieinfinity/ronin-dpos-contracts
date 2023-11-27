// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

type TPoolId is address;
type TConsensus is address;

using { TPoolIdEq as == } for TPoolId global;
using { TConsensusEq as == } for TConsensus global;

function TPoolIdEq(TPoolId a, TPoolId b) pure returns (bool) {
  return TPoolId.unwrap(a) == TPoolId.unwrap(b);
}

function TConsensusEq(TConsensus a, TConsensus b) pure returns (bool) {
  return TConsensus.unwrap(a) == TConsensus.unwrap(b);
}
