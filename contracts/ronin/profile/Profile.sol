// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../interfaces/staking/IStaking.sol";
import "../../interfaces/IProfile.sol";
import "./ProfileStorage.sol";

pragma solidity ^0.8.9;

contract Profile is IProfile, ProfileStorage, Initializable {
  constructor() {
    _disableInitializers();
  }

  /**
   * @inheritdoc IProfile
   */
  function getId2Profile(address id) external view returns (CandidateProfile memory) {
    return _id2Profile[id];
  }

  /**
   * @inheritdoc IProfile
   */
  function addNewProfile(CandidateProfile memory profile) external /* onlyAdmin */ {
    CandidateProfile storage _profile = _id2Profile[profile.id];
    if (_profile.id != address(0)) revert ErrExistentProfile();
    _addNewProfile(_profile, profile);
  }
}
