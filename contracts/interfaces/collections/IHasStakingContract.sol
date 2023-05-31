// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IHasContract.sol";

interface IHasStakingContract is IHasContract {
  /// @dev Emitted when the staking contract is updated.
  event StakingContractUpdated(address);

  /**
   * @dev Returns the staking contract.
   */
  function stakingContract() external view returns (address);

  /**
   * @dev Sets the staking contract.
   *
   * Requirements:
   * - The method caller is admin.
   * - The new address is a contract.
   *
   * Emits the event `StakingContractUpdated`.
   *
   */
  function setStakingContract(address) external;
}
