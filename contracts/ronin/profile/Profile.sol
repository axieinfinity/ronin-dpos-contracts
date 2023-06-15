// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../interfaces/IProfile.sol";
import "./ProfileInflow.sol";
import "./ProfileOutflow.sol";
import "./ProfileStorage.sol";

pragma solidity ^0.8.9;

contract Profile is IProfile, ProfileStorage, ProfileInflow, ProfileOutflow, Initializable {
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(address __stakingContract, address __validatorContract) external initializer {
    _setContract(ContractType.STAKING, __stakingContract);
    _setContract(ContractType.VALIDATOR, __validatorContract);
  }

  /**
   * @dev See {IProfile}
   */
  function getId2Profile(TPoolId id) external view returns (CandidateProfile memory) {
    return _id2Profile[id];
  }

  /**
   * @dev See {IProfile}
   */
  function getConsensus2Id(address consensus) external view returns (TPoolId id) {
    return _consensus2Id[consensus];
  }

  /**
   * @dev See {IProfile}
   */
  function getManyConsensus2Id(address[] calldata consensusList) external view returns (TPoolId[] memory idList) {
    idList = new TPoolId[](consensusList.length);
    unchecked {
      for (uint i; i < consensusList.length; ++i) {
        idList[i] = _consensus2Id[consensusList[i]];
      }
    }
  }

  /**
   * @dev See {IProfile}
   */
  function addNewProfile(CandidateProfile memory profile) external onlyAdmin {
    CandidateProfile storage _profile = _getId2ProfileHelper(profile.id);
    _addNewProfile(_profile, profile);
  }
}
