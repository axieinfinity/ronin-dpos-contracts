// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../interfaces/validator/IRoninValidatorSet.sol";
import "../../interfaces/IProfile.sol";
import { ErrUnauthorized, RoleAccess } from "../../utils/CommonErrors.sol";
import "./ProfileStorage.sol";

pragma solidity ^0.8.9;

contract Profile is IProfile, ProfileStorage, Initializable {
  constructor() {
    _disableInitializers();
  }

  function initialize(address validatorContract) external initializer {
    _setContract(ContractType.VALIDATOR, validatorContract);
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
  function addNewProfile(CandidateProfile memory profile) external onlyAdmin {
    CandidateProfile storage _profile = _id2Profile[profile.id];
    if (_profile.id != address(0)) revert ErrExistentProfile();
    _addNewProfile(_profile, profile);
  }

  /**
   * @inheritdoc IProfile
   */
  function registerProfile(CandidateProfile memory profile) external {
    CandidateProfile storage _profile = _id2Profile[profile.id];
    if (_profile.id != _profile.consensus) revert ErrIdAndConsensusDiffer();
    if (_profile.id != address(0)) revert ErrExistentProfile();
    if (
      msg.sender != profile.admin ||
      !IRoninValidatorSet(getContract(ContractType.VALIDATOR)).isCandidateAdmin(profile.consensus, profile.admin)
    ) revert ErrUnauthorized(msg.sig, RoleAccess.ADMIN);
    _checkDuplicatedInRegistry(profile);

    _addNewProfile(_profile, profile);
  }

  /**
   * @inheritdoc IProfile
   */
  function changePubkey(address id, bytes memory pubkey) external {
    CandidateProfile storage _profile = _getId2ProfileHelper(id);
    if (msg.sender != _profile.admin) revert ErrUnauthorized(msg.sig, RoleAccess.ADMIN);
    _checkDuplicatedPubkey(pubkey);

    _profile.pubkey = pubkey;
    _registry[_hashPubkey(pubkey)] = true;

    emit PubkeyChanged(id, pubkey);
  }
}
