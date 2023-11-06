// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IQuorum.sol";
import "../udvts/Types.sol";

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
   * @dev Error indicating that a governor address has already been added.
   * @param addr The address of the governor that is already added.
   */
  error ErrGovernorAddressIsAlreadyAdded(address addr);

  /**
   * @dev Error indicating that a consensus address is not added.
   * @param addr The address of the consensus contract that is not added.
   */
  error ErrConsensusAddressIsNotAdded(TConsensus addr);

  /**
   * @dev Error indicating that a consensus address is already added.
   * @param addr The address of the consensus contract that is already added.
   */
  error ErrConsensusAddressIsAlreadyAdded(TConsensus addr);

  struct TrustedOrganization {
    // Address of the validator that produces block, e.g. block.coinbase. This is so-called validator address.
    TConsensus consensusAddr;
    // Address to voting proposal
    address governor;
    // Address to voting bridge operators
    address __deprecatedBridgeVoter;
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
  event TrustedOrganizationsRemoved(TConsensus[] orgs);
  /// @dev Emitted when the consensus address of a trusted organization is changed.
  event ConsensusAddressOfTrustedOrgChanged(TrustedOrganization orgAfterChanged, TConsensus oldConsensus);

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
  function updateTrustedOrganizations(TrustedOrganization[] calldata list) external;

  /**
   * @dev Removes a list of addresses from the trusted organization.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the event `TrustedOrganizationRemoved` once an organization is removed.
   *
   * @param consensusAddrs The list of consensus addresses linked to corresponding trusted organization that to be removed.
   */
  function removeTrustedOrganizations(TConsensus[] calldata consensusAddrs) external;

  /**
   * @dev Fallback function of `Profile-requestChangeConsensusAddress`.
   *
   * Requirements:
   * - The caller must be the Profile contract.
   *
   * Emits the event `ConsensusAddressOfTrustedOrgChanged` once an organization is removed.
   */
  function execChangeConsensusAddressForTrustedOrg(TConsensus oldConsensusAddr, TConsensus newConsensusAddr) external;

  /**
   * @dev Returns total weights.
   */
  function totalWeight() external view returns (uint256);

  /**
   * @dev Returns the weight of a consensus.
   */
  function getConsensusWeight(TConsensus consensusAddr) external view returns (uint256);

  /**
   * @dev Returns the weight of a consensus.
   */
  function getConsensusWeightById(address cid) external view returns (uint256);

  /**
   * @dev Returns the weight of a governor.
   */
  function getGovernorWeight(address governor) external view returns (uint256);

  /**
   * @dev Returns the weight of a bridge voter.
   */
  function getBridgeVoterWeight(address _addr) external view returns (uint256);

  /**
   * @dev Returns the weights of a list of consensus addresses.
   */
  function getConsensusWeights(TConsensus[] calldata list) external view returns (uint256[] memory);

  /**
   * @dev Returns the weights of a list of consensus addresses.
   */
  function getManyConsensusWeightsById(address[] calldata cids) external view returns (uint256[] memory);

  /**
   * @dev Returns the weights of a list of governor addresses.
   */
  function getGovernorWeights(address[] calldata list) external view returns (uint256[] memory);

  /**
   * @dev Returns the weights of a list of bridge voter addresses.
   */
  function getBridgeVoterWeights(address[] calldata _list) external view returns (uint256[] memory);

  /**
   * @dev Returns total weights of the consensus list.
   */
  function sumConsensusWeight(TConsensus[] calldata list) external view returns (uint256 _res);

  /**
   * @dev Returns total weights of the governor list.
   */
  function sumGovernorWeight(address[] calldata list) external view returns (uint256 _res);

  /**
   * @dev Returns the trusted organization at `_index`.
   */
  function getTrustedOrganizationAt(uint256 index) external view returns (TrustedOrganization memory);

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
  function getTrustedOrganization(TConsensus consensusAddr) external view returns (TrustedOrganization memory);
}
