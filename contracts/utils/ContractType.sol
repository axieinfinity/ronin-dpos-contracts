// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

enum ContractType {
  /*  0 */ UNKNOWN,
  /*  1 */ PAUSE_ENFORCER,
  /*  2 */ BRIDGE,
  /*  3 */ BRIDGE_TRACKING,
  /*  4 */ GOVERNANCE_ADMIN,
  /*  5 */ MAINTENANCE,
  /*  6 */ SLASH_INDICATOR,
  /*  7 */ STAKING_VESTING,
  /*  8 */ VALIDATOR,
  /*  9 */ STAKING,
  /* 10 */ RONIN_TRUSTED_ORGANIZATION,
  /* 11 */ BRIDGE_MANAGER,
  /* 12 */ BRIDGE_SLASH,
  /* 13 */ BRIDGE_REWARD,
  /* 14 */ FAST_FINALITY_TRACKING,
  /* 15 */ PROFILE
}
