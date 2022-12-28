// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IHasContract.sol";

interface IHasStakingVestingContract is IHasContract {
  /// @dev Emitted when the staking vesting contract is updated.
  event StakingVestingContractUpdated(address);

  /// @dev Error of method caller must be staking vesting contract.
  error ErrCallerMustBeStakingVestingContract();

  /**
   * @dev Returns the staking vesting contract.
   */
  function stakingVestingContract() external view returns (address);

  /**
   * @dev Sets the staking vesting contract.
   *
   * Requirements:
   * - The method caller is admin.
   * - The new address is a contract.
   *
   * Emits the event `StakingVestingContractUpdated`.
   *
   */
  function setStakingVestingContract(address) external;
}
