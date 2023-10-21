// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

enum RoleAccess {
  /* 0 */ UNKNOWN,
  /* 1 */ ADMIN,
  /* 2 */ COINBASE,
  /* 3 */ GOVERNOR,
  /* 4 */ CANDIDATE_ADMIN,
  /* 5 */ WITHDRAWAL_MIGRATOR,
  /* 6 */ __DEPRECATED_BRIDGE_OPERATOR,
  /* 7 */ BLOCK_PRODUCER,
  /* 8 */ VALIDATOR_CANDIDATE,
  /* 9 */ CONSENSUS,
  /* 10 */ TREASURY
}
