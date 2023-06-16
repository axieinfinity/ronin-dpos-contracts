// SPDX-License-Identifier: MIT

import "./ProfileStorage.sol";
import "../../interfaces/staking/IStaking.sol";
import "../../extensions/collections/HasContracts.sol";
import "../../utils/RoleAccess.sol";
import { ContractType } from "../../utils/ContractType.sol";

pragma solidity ^0.8.9;

abstract contract ProfileInflow is HasContracts, ProfileStorage {
  /**
   * @dev Updated immediately without waiting time.
   *
   * Interactions: // TODO: remove following part when cleaning up code
   * - Update `PoolDetail` in {BaseStaking.sol}.
   * - Update `_adminOfActivePoolMapping` in {BaseStaking.sol}.
   *
   * Emit an {ProfileAddressChanged}.
   */
  function requestChangeAdminAddress(address id, address newAdminAddr) external {
    IStaking stakingContract = IStaking(getContract(ContractType.STAKING));
    stakingContract.execChangeAdminAddress(id, newAdminAddr);

    CandidateProfile storage _profile = _getId2ProfileHelper(id);
    _profile.admin = newAdminAddr;

    emit ProfileAddressChanged(id, RoleAccess.ADMIN);
  }

  /**
   * @dev Updated immediately without waiting time. (???)
   *
   * Interactions: // TODO: remove following part when cleaning up code
   * - Update in Staking contract for Consensus address mapping:
   *   + [x] Keep the same previous pool address. // CHECKED, NO NEED ANY CHANGES
   *   +
   * - Update in Validator contract for:
   *   + Consensus Address mapping
   *   + Bridge Address mapping
   *   + Jail mapping
   *   + Pending reward mapping
   *   + Schedule mapping
   * - Update in Proposal contract for:
   *   + Refund of emergency exit mapping
   *   + ...
   *
   * Emit an {ProfileAddressChanged}.
   *
   */
  function requestChangeConsensusAddr(address id, TConsensus newConsensusAddr) external {
    CandidateProfile storage _profile = _getId2ProfileHelper(id);

    _profile.consensus = newConsensusAddr;

    emit ProfileAddressChanged(id, RoleAccess.CONSENSUS);
  }
}
