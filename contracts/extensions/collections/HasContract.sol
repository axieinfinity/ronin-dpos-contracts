// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./HasProxyAdmin.sol";
import "../../interfaces/collections/IHasContract.sol";

/**
 * @title HasContract
 * @dev A contract that provides functionality to manage multiple contracts with different roles.
 */
abstract contract HasContract is HasProxyAdmin, IHasContract {
  /// @dev value is equal to keccak256("@ronin.dpos.collections.HasContract.slot") - 1
  bytes32 private constant _STORAGE_SLOT = 0xfad9c0674683fb431b376631a4bfc80edfff393989fa2d275a376234d8cd59ac;

  /**
   * @dev Modifier to restrict access to functions only to contracts with a specific role.
   * @param role The role that the calling contract must have.
   */
  modifier onlyContractWithRole(Role role) virtual {
    _requireRoleContract(role);
    _;
  }

  /**
   * @inheritdoc IHasContract
   */
  function setContract(Role role, address addr) external virtual onlyAdmin {
    _requireHasCode(addr);
    _setContract(role, addr);
  }

  /**
   * @inheritdoc IHasContract
   */
  function getContract(Role role) public view returns (address contract_) {
    contract_ = _getContractMap()[uint8(role)];
    if (contract_ == address(0)) revert ErrInvalidRoleContract(role);
  }

  /**
   * @dev Internal function to set the address of a contract with a specific role.
   * @param role The role of the contract to set.
   * @param addr The address of the contract to set.
   */
  function _setContract(Role role, address addr) internal virtual {
    _getContractMap()[uint8(role)] = addr;
    emit ContractUpdated(role, addr);
  }

  /**
   * @dev Internal function to check if a contract address has code.
   * @param addr The address of the contract to check.
   * @dev Throws an error if the contract address has no code.
   */
  function _requireHasCode(address addr) internal view {
    if (addr.code.length == 0) revert ErrZeroCodeContract(addr);
  }

  /**
   * @dev Internal function to access the mapping of contract addresses with roles.
   * @return contracts_ The mapping of contract addresses with roles.
   */
  function _getContractMap() private pure returns (mapping(uint8 => address) storage contracts_) {
    assembly {
      contracts_.slot := _STORAGE_SLOT
    }
  }

  /**
   * @dev Internal function to check if the calling contract has a specific role.
   * @param role The role that the calling contract must have.
   * @dev Throws an error if the calling contract does not have the specified role.
   */
  function _requireRoleContract(Role role) private view {
    if (msg.sender != getContract(role)) revert ErrUnauthorized(msg.sig, role);
  }
}
