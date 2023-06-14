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
    TPoolId poolAddr,
    address newAdminAddr
  ) external override onlyContract(ContractType.PROFILE) {
    PoolDetail storage _pool = _poolDetail[poolAddr];

    _adminOfActivePoolMapping[_pool.admin] = TPoolId.wrap(address(0));
    _pool.admin = newAdminAddr;
    _adminOfActivePoolMapping[newAdminAddr] = poolAddr;
  }
}
