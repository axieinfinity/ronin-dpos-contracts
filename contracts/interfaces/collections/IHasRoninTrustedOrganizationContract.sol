// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IHasRoninTrustedOrganizationContract {
  /// @dev Emitted when the ronin trusted organization contract is updated.
  event RoninTrustedOrganizationContractUpdated(address);

  /**
   * @dev Returns the ronin trusted organization contract.
   */
  function roninTrustedOrganizationContract() external view returns (address);

  /**
   * @dev Sets the ronin trusted organization contract.
   *
   * Requirements:
   * - The method caller is admin.
   * - The new address is a contract.
   *
   * Emits the event `RoninTrustedOrganizationContractUpdated`.
   *
   */
  function setRoninTrustedOrganizationContract(address) external;
}
