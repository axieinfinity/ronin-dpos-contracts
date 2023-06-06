// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev Sort role by contract or eoa in parity order.
 * @notice 1st bit is reserved
 * @notice EOA is even (*0), contract is odd (*1)
 */
enum Roles {
  UNKNOWN_0, // 0
  UNKNOWN_1, // 1
  ADMIN, // 2
  PAUSE_ENFORCER_CONTRACT, // 3
  COINBASE, // 4
  BRIDGE_CONTRACT, // 5
  GOVERNOR, // 6
  BRIDGE_TRACKING_CONTRACT, // 7
  CANDIDATE_ADMIN, // 8
  GOVERNANCE_ADMIN_CONTRACT, // 9
  WITHDRAWAL_MIGRATOR, // 10
  MAINTENANCE_CONTRACT, // 11
  BRIDGE_OPERATOR, // 12
  SLASH_INDICATOR_CONTRACT, // 13
  BLOCK_PRODUCER, // 14
  STAKING_VESTING_CONTRACT, // 15
  VALIDATOR_CANDIDATE, // 16
  VALIDATOR_CONTRACT, // 17
  RESERVE_0, // 18
  STAKING_CONTRACT, // 19
  RESERVE_1, // 20
  RONIN_TRUSTED_ORGANIZATION_CONTRACT // 21
}
