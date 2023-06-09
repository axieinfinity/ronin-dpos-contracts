// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @notice Sort role by contract or EOA in parity order.
 * @dev The 1st (the right bit) most is reserved. EOA addresses are even (`*0`), contract addresses are odd (`*1`)
 */
enum Role {
  /*  0 */ UNKNOWN_0,
  /*  1 */ UNKNOWN_1,
  /*  2 */ ADMIN,
  /*  3 */ PAUSE_ENFORCER_CONTRACT,
  /*  4 */ COINBASE,
  /*  5 */ BRIDGE_CONTRACT,
  /*  6 */ GOVERNOR,
  /*  7 */ BRIDGE_TRACKING_CONTRACT,
  /*  8 */ CANDIDATE_ADMIN,
  /*  9 */ GOVERNANCE_ADMIN_CONTRACT,
  /* 10 */ WITHDRAWAL_MIGRATOR,
  /* 11 */ MAINTENANCE_CONTRACT,
  /* 12 */ BRIDGE_OPERATOR,
  /* 13 */ SLASH_INDICATOR_CONTRACT,
  /* 14 */ BLOCK_PRODUCER,
  /* 15 */ STAKING_VESTING_CONTRACT,
  /* 16 */ VALIDATOR_CANDIDATE,
  /* 17 */ VALIDATOR_CONTRACT,
  /* 18 */ RESERVED_0,
  /* 19 */ STAKING_CONTRACT,
  /* 20 */ RESERVED_1,
  /* 21 */ RONIN_TRUSTED_ORGANIZATION_CONTRACT
}
