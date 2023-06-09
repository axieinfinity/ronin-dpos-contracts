// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../libraries/Role.sol";

interface IHasContracts {
  /// @dev Error of invalid role.
  error ErrInvalidRoleContract(Role role);
  /// @dev Error of set to non-contract.
  error ErrZeroCodeContract(address addr);

  /// @dev Emitted when a contract is updated.
  event ContractUpdated(Role indexed role, address indexed addr);

  /**
   * @dev Returns the address of a contract with a specific role.
   * Throws an error if no contract is set for the specified role.
   *
   * @param role The role of the contract to retrieve.
   * @return contract_ The address of the contract with the specified role.
   */
  function getContract(Role role) external view returns (address contract_);

  /**
   * @dev Sets the address of a contract with a specific role.
   * @param role The role of the contract to set.
   * @param addr The address of the contract to set.
   */
  function setContract(Role role, address addr) external;
}
