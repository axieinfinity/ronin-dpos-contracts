// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../extensions/collections/HasStakingContract.sol";
import "../interfaces/IProfile.sol";

pragma solidity ^0.8.9;

contract Profile is IProfile, HasStakingContract, Initializable {
  /// @dev Mapping from id address => candidate profile.
  mapping(address => CandidateProfile) public _id2Profile;
  /// @dev Mapping from consensus address => id address.
  mapping(address => address) public _consensus2Id;

  /// @dev Event emitted when a profile with `id` is added.
  event ProfileAdded(address indexed id);

  /// @dev Error of already existed profile.
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
    unchecked {
      for (uint i; i < consensusList.length; ++i) {
        idList[i] = _consensus2Id[consensusList[i]];
      }
    }
  }

  function addNewProfile(CandidateProfile memory profile) external onlyAdmin {
    CandidateProfile storage _profile = _id2Profile[profile.id];
    if (_profile.id != address(0)) revert ErrExistentProfile();
    _addNewProfile(_profile, profile);
  }

  function execApplyValidatorCandidate(
    address admin,
    address consensus,
    address treasury,
    address bridgeOperator
  ) external onlyStakingContract {
    // TODO: handle previous added consensus
    CandidateProfile storage _profile = _id2Profile[consensus];

    CandidateProfile memory mProfile = CandidateProfile({
      id: consensus,
      consensus: consensus,
      admin: admin,
      treasury: payable(treasury),
      bridgeOperator: bridgeOperator,
      governor: address(0),
      bridgeVoter: address(0)
    });

    _addNewProfile(_profile, mProfile);
  }

  function _addNewProfile(CandidateProfile storage _profile, CandidateProfile memory mNewProfile) internal {
    _consensus2Id[mNewProfile.consensus] = mNewProfile.id;

    _profile.id = mNewProfile.id;
    _profile.consensus = mNewProfile.consensus;
    _profile.admin = mNewProfile.admin;
    _profile.treasury = mNewProfile.treasury;
    _profile.bridgeOperator = mNewProfile.bridgeOperator;
    _profile.governor = mNewProfile.governor;
    _profile.bridgeVoter = mNewProfile.bridgeVoter;

    emit ProfileAdded(mNewProfile.id);
  }
}
