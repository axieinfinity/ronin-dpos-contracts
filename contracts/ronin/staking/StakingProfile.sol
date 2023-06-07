// SPDX-License-Identifier: MIT

import "./CandidateStaking.sol";
import "./DelegatorStaking.sol";

pragma solidity ^0.8.9;

abstract contract StakingProfile is CandidateStaking, DelegatorStaking {
  /**
   * @dev Requirements:
   * - Only Profile contract can call this method.
   */
  function execChangeAdminAddress(address poolAddr, address newAdminAddr) external onlyProfileContract {
    PoolDetail storage _pool = _stakingPool[poolAddr];

    delete _adminOfActivePoolMapping[_pool.admin];
    _pool.admin = newAdminAddr;
    _adminOfActivePoolMapping[newAdminAddr] = poolAddr;
  }
}
