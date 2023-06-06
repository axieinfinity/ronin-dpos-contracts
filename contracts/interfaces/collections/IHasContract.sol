// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../libraries/Roles.sol";

interface IHasContract {
  error ErrInvalidRoleContract(Roles role);
  /// @dev Error of set to non-contract.
  error ErrZeroCodeContract(address addr);

  event ContractUpdated(Roles indexed role, address indexed addr);

  /**
   * @dev Returns the address of a contract with a specific role.
   * @param role The role of the contract to retrieve.
   * @return contract_ The address of the contract with the specified role.
   * @dev Throws an error if no contract is set for the specified role.
   */
  function getContract(Roles role) external view returns (address contract_);

  /**
   * @dev Sets the address of a contract with a specific role.
   * @param role The role of the contract to set.
   * @param addr The address of the contract to set.
   */
  function setContract(Roles role, address addr) external;
}
