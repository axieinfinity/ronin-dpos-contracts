// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { TConsensus } from "../../udvts/Types.sol";

interface ICandidateManagerCallback {
  /**
   * @dev Fallback function of `Profile-requestChangeAdminAddress`.
   * This updates the shadow storage slot of "shadowedAdmin" for candidate id `id` to `newAdmin`.
   *
   * Requirements:
   * - The caller must be the Profile contract.
   */
  function execChangeAdminAddress(address cid, address newAdmin) external;

  /**
   * @dev Fallback function of `Profile-requestChangeConsensusAddress`.
   * This updates the shadow storage slot of "shadowedConsensus" for candidate id `id` to `newAdmin`.
   *
   * Requirements:
   * - The caller must be the Profile contract.
   */
  function execChangeConsensusAddress(address cid, TConsensus newConsensus) external;

  /**
   * @dev Fallback function of `Profile-requestChangeTreasuryAddress`.
   * This updates the shadow storage slot of "shadowedTreasury" for candidate id `id` to `newAdmin`.
   *
   * Requirements:
   * - The caller must be the Profile contract.
   */
  function execChangeTreasuryAddress(address cid, address payable newTreasury) external;
}
