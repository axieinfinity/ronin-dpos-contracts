// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../extensions/collections/HasStakingContract.sol";

pragma solidity ^0.8.9;

interface IProfile {
  struct CandidateProfile {
    /**
     * @dev Primary key of the profile, use for backward querying.
     *
     * {Staking} Contract: index of pool
     * {RoninValidatorSet} Contract: index of almost all data related to a validator
     *
     */
    address id;
    /// @dev Consensus address.
    address consensus;
    /// @dev Pool admin address.
    address admin;
    /// @dev Treasury address.
    address payable treasury;
    /// @dev Address of the bridge operator corresponding to the candidate.
    address bridgeOperator;
    /// @dev Address to voting proposal.
    address governor;
    /// @dev Address to voting bridge operators.
    address bridgeVoter;
  }

  function getId2Profile(address id) external view returns (CandidateProfile memory);

  function getConsensus2Id(address consensus) external view returns (address id);

  function execApplyValidatorCandidate(
    address admin,
    address consensus,
    address treasury,
    address bridgeOperator
  ) external;
}

contract Profile is IProfile, HasStakingContract, Initializable {
  /// @dev Mapping from id address => candidate profile.
  mapping(address => CandidateProfile) public _id2Profile;
  /// @dev Mapping from consensus address => id address.
  mapping(address => address) public _consensus2Id;

  event ProfileAdded(address indexed id);

  error ErrExistentProfile();

  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(address __stakingContract) external initializer {
    _setStakingContract(__stakingContract);
  }

  function getId2Profile(address id) external view returns (CandidateProfile memory) {
    return _id2Profile[id];
  }

  function getConsensus2Id(address consensus) external view returns (address id) {
    return _consensus2Id[consensus];
  }

  function getManyConsensus2Id(address[] calldata consensusList) external view returns (address[] memory idList) {
    idList = new address[](consensusList.length);
    for (uint i; i < consensusList.length; ) {
      idList[i] = _consensus2Id[consensusList[i]];
      unchecked {
        ++i;
      }
    }
  }

  function addNewProfile(CandidateProfile memory _profile) external onlyAdmin {
    CandidateProfile storage sProfile = _id2Profile[_profile.id];
    if (sProfile.id != address(0)) revert ErrExistentProfile();
    _addNewProfile(sProfile, _profile);
  }

  function execApplyValidatorCandidate(
    address _admin,
    address _consensus,
    address _treasury,
    address _bridgeOperator
  ) external {
    // TODO: handle previous added consensus
    CandidateProfile storage sProfile = _id2Profile[_consensus];

    CandidateProfile memory _profile = CandidateProfile(
      _consensus,
      _admin,
      _consensus,
      payable(_treasury),
      _bridgeOperator,
      address(0),
      address(0)
    );

    _addNewProfile(sProfile, _profile);
  }

  function _addNewProfile(CandidateProfile storage _sProfile, CandidateProfile memory _newProfile) internal {
    _consensus2Id[_newProfile.consensus] = _newProfile.id;

    _sProfile.id = _newProfile.id;
    _sProfile.consensus = _newProfile.consensus;
    _sProfile.admin = _newProfile.admin;
    _sProfile.treasury = _newProfile.treasury;
    _sProfile.bridgeOperator = _newProfile.bridgeOperator;
    _sProfile.governor = _newProfile.governor;
    _sProfile.bridgeVoter = _newProfile.bridgeVoter;

    emit ProfileAdded(_newProfile.id);
  }
}
