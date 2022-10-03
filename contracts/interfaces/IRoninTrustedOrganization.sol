// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IRoninTrustedOrganization {
  /// @dev Emitted when the trusted organizations are added.
  event TrustedOrganizationsAdded(address[]);
  /// @dev Emitted when the trusted organizations are removed.
  event TrustedOrganizationsRemoved(address[]);

  /**
   * @dev Adds a list of addesses into the trusted organizations.
   *
   * Requirements:
   * - The method caller is admin.
   *
   */
  function addTrustedOrganizations(address[] calldata) external;

  /**
   * @dev Removes a list of addesses from the trusted organizations.
   *
   * Requirements:
   * - The method caller is admin.
   *
   */
  function removeTrustedOrganizations(address[] calldata) external;

  /**
   * @dev Returns whether the addresses are trusted organizations.
   */
  function isTrustedOrganizations(address[] calldata) external view returns (bool[] memory);

  /**
   * @dev Returns the trusted organizations at the position.
   */
  function getTrustedOrganizationAt(uint256) external view returns (address);

  /**
   * @dev Returns the number of trusted organizations.
   */
  function countTrustedOrganizations() external view returns (uint256);

  /**
   * @dev Returns all of the trusted organization addresses.
   */
  function getAllTrustedOrganizations() external view returns (address[] memory);
}
