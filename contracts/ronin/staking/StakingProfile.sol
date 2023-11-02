// SPDX-License-Identifier: MIT

import "../../interfaces/IProfile.sol";
import "../../interfaces/staking/IStakingProfile.sol";
import "./CandidateStaking.sol";
import "./DelegatorStaking.sol";

pragma solidity ^0.8.9;

abstract contract StakingProfile is CandidateStaking, DelegatorStaking, IStakingProfile {
  /**
   * @dev Requirements:
   * - Only Profile contract can call this method.
   */
  function execChangeAdminAddress(
    address poolAddr,
    address newAdminAddr
  ) external override onlyContract(ContractType.PROFILE) {
    PoolDetail storage _pool = _poolDetail[poolAddr];

    _adminOfActivePoolMapping[_pool.__shadowedPoolAdmin] = address(0);
    _pool.__shadowedPoolAdmin = newAdminAddr;
    _adminOfActivePoolMapping[newAdminAddr] = poolAddr;
  }
}
