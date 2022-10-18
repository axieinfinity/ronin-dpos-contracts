// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./consumers/WeightedAddressConsumer.sol";
import "./IQuorum.sol";

interface IRoninTrustedOrganization is WeightedAddressConsumer, IQuorum {
  /// @dev Emitted when the trusted organization is added.
  event TrustedOrganizationAdded(WeightedAddress org);
  /// @dev Emitted when the trusted organization is updated.
  event TrustedOrganizationUpdated(WeightedAddress org);
  /// @dev Emitted when the trusted organization is removed.
  event TrustedOrganizationRemoved(address org);

  /**
   * @dev Adds a list of addresses into the trusted organization.
   *
   * Requirements:
   * - The weights should larger than 0.
   * - The method caller is admin.
   *
   * Emits the event `TrustedOrganizationAdded` once an organization is added.
   *
   */
  function addTrustedOrganizations(WeightedAddress[] calldata) external;

  /**
   * @dev Updates weights for a list of existent trusted organization.
   *
   * Requirements:
   * - The weights should larger than 0.
   * - The method caller is admin.
   *
   * Emits the `TrustedOrganizationUpdated` event.
   *
   */
  function updateTrustedOrganizations(WeightedAddress[] calldata _list) external;

  /**
   * @dev Removes a list of addresses from the trusted organization.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the event `TrustedOrganizationRemoved` once an organization is removed.
   *
   */
  function removeTrustedOrganizations(address[] calldata) external;

  /**
   * @dev Returns total weights.
   */
  function totalWeights() external view returns (uint256);

  /**
   * @dev Returns the weight of an address.
   */
  function getWeight(address _addr) external view returns (uint256);

  /**
   * @dev Returns the weights of a list of addresses.
   */
  function getWeights(address[] calldata _list) external view returns (uint256[] memory);

  /**
   * @dev Returns total weights of the address list.
   */
  function sumWeights(address[] calldata _list) external view returns (uint256 _res);

  /**
   * @dev Returns the trusted organization at `_index`.
   */
  function getTrustedOrganizationAt(uint256 _index) external view returns (WeightedAddress memory);

  /**
   * @dev Returns the number of trusted organizations.
   */
  function countTrustedOrganizations() external view returns (uint256);

  /**
   * @dev Returns all of the trusted organization addresses.
   */
  function getAllTrustedOrganizations() external view returns (WeightedAddress[] memory);
}
