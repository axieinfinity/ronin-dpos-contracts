// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IQuorum.sol";

interface IRoninTrustedOrganization is IQuorum {
  /**
   * @dev Error indicating that a query for a duplicate entry was made.
   */
  error ErrQueryForDupplicated();

  /**
   * @dev Error indicating that a query was made for a non-existent consensus address.
   */
  error ErrQueryForNonExistentConsensusAddress();

  /**
   * @dev Error indicating that a bridge voter has already been added.
   * @param voter The address of the bridge voter that is already added.
   */
  error ErrBridgeVoterIsAlreadyAdded(address voter);

  /**
   * @dev Error indicating that a governor address has already been added.
   * @param addr The address of the governor that is already added.
   */
  error ErrGovernorAddressIsAlreadyAdded(address addr);

  /**
   * @dev Error indicating that a consensus address is not added.
   * @param addr The address of the consensus contract that is not added.
   */
  error ErrConsensusAddressIsNotAdded(address addr);

  /**
   * @dev Error indicating that a consensus address is already added.
   * @param addr The address of the consensus contract that is already added.
   */
  error ErrConsensusAddressIsAlreadyAdded(address addr);

  struct TrustedOrganization {
    // Address of the validator that produces block, e.g. block.coinbase. This is so-called validator address.
    address consensusAddr;
    // Address to voting proposal
    address governor;
    // Address to voting bridge operators
    address bridgeVoter;
    // Its Weight
    uint256 weight;
    // The block that the organization was added
    uint256 addedBlock;
  }

  /// @dev Emitted when the trusted organization is added.
  event TrustedOrganizationsAdded(TrustedOrganization[] orgs);
  /// @dev Emitted when the trusted organization is updated.
  event TrustedOrganizationsUpdated(TrustedOrganization[] orgs);
  /// @dev Emitted when the trusted organization is removed.
  event TrustedOrganizationsRemoved(address[] orgs);

  /**
   * @dev Adds a list of addresses into the trusted organization.
   *
   * Requirements:
   * - The weights should larger than 0.
   * - The method caller is admin.
   * - The field `addedBlock` should be blank.
   *
   * Emits the event `TrustedOrganizationAdded` once an organization is added.
   *
   */
  function addTrustedOrganizations(TrustedOrganization[] calldata) external;

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
  function updateTrustedOrganizations(TrustedOrganization[] calldata _list) external;

  /**
   * @dev Removes a list of addresses from the trusted organization.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the event `TrustedOrganizationRemoved` once an organization is removed.
   *
   * @param _consensusAddrs The list of consensus addresses linked to corresponding trusted organization that to be removed.
   */
  function removeTrustedOrganizations(address[] calldata _consensusAddrs) external;

  /**
   * @dev Returns total weights.
   */
  function totalWeight() external view returns (uint256);

  /**
   * @dev Returns the weight of a consensus.
   */
  function getConsensusWeight(address _consensusAddr) external view returns (uint256);

  /**
   * @dev Returns the weight of a governor.
   */
  function getGovernorWeight(address _governor) external view returns (uint256);

  /**
   * @dev Returns the weight of a bridge voter.
   */
  function getBridgeVoterWeight(address _addr) external view returns (uint256);

  /**
   * @dev Returns the weights of a list of consensus addresses.
   */
  function getConsensusWeights(address[] calldata _list) external view returns (uint256[] memory);

  /**
   * @dev Returns the weights of a list of governor addresses.
   */
  function getGovernorWeights(address[] calldata _list) external view returns (uint256[] memory);

  /**
   * @dev Returns the weights of a list of bridge voter addresses.
   */
  function getBridgeVoterWeights(address[] calldata _list) external view returns (uint256[] memory);

  /**
   * @dev Returns total weights of the consensus list.
   */
  function sumConsensusWeight(address[] calldata _list) external view returns (uint256 _res);

  /**
   * @dev Returns total weights of the governor list.
   */
  function sumGovernorWeight(address[] calldata _list) external view returns (uint256 _res);

  /**
   * @dev Returns total weights of the bridge voter list.
   */
  function sumBridgeVoterWeight(address[] calldata _list) external view returns (uint256 _res);

  /**
   * @dev Returns the trusted organization at `_index`.
   */
  function getTrustedOrganizationAt(uint256 _index) external view returns (TrustedOrganization memory);

  /**
   * @dev Returns the number of trusted organizations.
   */
  function countTrustedOrganization() external view returns (uint256);

  /**
   * @dev Returns all of the trusted organizations.
   */
  function getAllTrustedOrganizations() external view returns (TrustedOrganization[] memory);

  /**
   * @dev Returns the trusted organization by consensus address.
   *
   * Reverts once the consensus address is non-existent.
   */
  function getTrustedOrganization(address _consensusAddr) external view returns (TrustedOrganization memory);
}
