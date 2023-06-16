// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { TPoolId } from "../../udvts/Types.sol";

interface IStakingProfile {
  /**
   * @dev Requirements:
   * - Only Profile contract can call this method.
   */
  function execChangeAdminAddress(address poolAddr, address newAdminAddr) external;
}
