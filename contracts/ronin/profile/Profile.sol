// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../interfaces/validator/ICandidateManager.sol";
import "../../interfaces/validator/IRoninValidatorSet.sol";
import "../../interfaces/IProfile.sol";
import { ErrUnauthorized, RoleAccess } from "../../utils/CommonErrors.sol";
import { ContractType } from "../../utils/ContractType.sol";
import "./ProfileHandler.sol";

pragma solidity ^0.8.9;

contract Profile is IProfile, ProfileHandler, Initializable {
  constructor() {
    _disableInitializers();
  }

  function initialize(address validatorContract) external initializer {
    _setContract(ContractType.VALIDATOR, validatorContract);
  }

  function migrateTestnet() external {
    require(block.chainid == 2021, "mismatch chainID");
    require(msg.sender == 0x968D0Cd7343f711216817E617d3f92a23dC91c07, "not testnet admin");

    CandidateProfile storage _profile;

    address[10] memory consensusList = [
      0xCaba9D9424D6bAD99CE352A943F59279B533417a,
      0x9f1Abc67beA4db5560371fF3089F4Bfe934c36Bc,
      0xA85ddDdCeEaB43DccAa259dd4936aC104386F9aa,
      0xAcf8Bf98D1632e602d0B1761771049aF21dd6597,
      0xE9bf2A788C27dADc6B169d52408b710d267b9bff,
      0xD086D2e3Fac052A3f695a4e8905Ce1722531163C,
      // 0x9687e8C41fa369aD08FD278a43114C4207856a61, // missing
      0xa325Fd3a2f4f5CafE2c151eE428b5CeDeD628193,
      0x9422d990AcDc3f2b3AA3B97303aD3060F09d7ffC,
      0xc3C97512421BF3e339E9fd412f18584e53138bFA,
      0x78fD38faa30ea66702cc39383D2E84f9a4A56fA6
    ];

    for (uint i; i < consensusList.length; i++) {
      _migrateTestnetHelper(consensusList[i]);
    }

    {
      _profile = _getId2ProfileHelper(0xCaba9D9424D6bAD99CE352A943F59279B533417a);
      _setGovernor(_profile, 0xb033ba62EC622dC54D0ABFE0254e79692147CA26);
    }
    {
      _profile = _getId2ProfileHelper(0x9f1Abc67beA4db5560371fF3089F4Bfe934c36Bc);
      _setGovernor(_profile, 0x087D08e3ba42e64E3948962dd1371F906D1278b9);
    }
    {
      _profile = _getId2ProfileHelper(0xA85ddDdCeEaB43DccAa259dd4936aC104386F9aa);
      _setGovernor(_profile, 0x52ec2e6BBcE45AfFF8955Da6410bb13812F4289F);
    }
    {
      _profile = _getId2ProfileHelper(0xAcf8Bf98D1632e602d0B1761771049aF21dd6597);
      _setGovernor(_profile, 0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa);
    }
  }

  function migrateTestnetManual(address consensus, address governor) external {
    require(block.chainid == 2021, "mismatch chainID");
    require(msg.sender == 0x968D0Cd7343f711216817E617d3f92a23dC91c07, "not testnet admin");

    _migrateTestnetHelper(consensus);
    if (governor != address(0)) {
      CandidateProfile storage _profile = _getId2ProfileHelper(consensus);
      _setGovernor(_profile, governor);
    }
  }

  function _migrateTestnetHelper(address consensus) internal {
    CandidateProfile storage _profile = _getId2ProfileHelper(consensus);
    ICandidateManager.ValidatorCandidate memory info = IRoninValidatorSet(getContract(ContractType.VALIDATOR))
      .getCandidateInfo(consensus);
    _setConsensus(_profile, consensus);
    _setAdmin(_profile, info.admin);
    _setTreasury(_profile, payable(info.treasuryAddr));
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
    if (profile.id != profile.consensus) revert ErrIdAndConsensusDiffer();

    CandidateProfile storage _profile = _id2Profile[profile.id];
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
    _checkNonDuplicatedPubkey(pubkey);
    _setPubkey(_profile, pubkey);

    emit PubkeyChanged(id, pubkey);
  }
}
