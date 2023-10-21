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

  function migrateMainnetV2() external {
    require(block.chainid == 2020, "mismatch chainID");
    require(msg.sender == 0x4d58Ea7231c394d5804e8B06B1365915f906E27F, "not mainnet deployer");

    address[29] memory consensusList = [
      0x52C0dcd83aa1999BA6c3b0324C8299E30207373C,
      0xf41Af21F0A800dc4d86efB14ad46cfb9884FDf38,
      0xE07D7e56588a6FD860c5073c70a099658C060F3D,
      0x52349003240770727900b06a3B3a90f5c0219ADe,
      0x2bdDcaAE1C6cCd53E436179B3fc07307ee6f3eF8,
      0xeC702628F44C31aCc56C3A59555be47e1f16eB1e,
      0xbD4bf317Da1928CC2f9f4DA9006401f3944A0Ab5,
      0xd11D9842baBd5209b9B1155e46f5878c989125b7,
      0x61089875fF9e506ae78C7FE9f7c388416520E386,
      0xD7fEf73d95ccEdb26483fd3C6C48393e50708159,
      0x47cfcb64f8EA44d6Ea7FAB32f13EFa2f8E65Eec1,
      0x8Eec4F1c0878F73E8e09C1be78aC1465Cc16544D,
      0x9B959D27840a31988410Ee69991BCF0110D61F02,
      0xEE11d2016e9f2faE606b2F12986811F4abbe6215,
      0xca54a1700e0403Dcb531f8dB4aE3847758b90B01,
      0x4E7EA047EC7E95c7a02CB117128B94CCDd8356bf,
      0x6E46924371d0e910769aaBE0d867590deAC20684,
      0xae53daAC1BF3c4633d4921B8C3F8d579e757F5Bc,
      0x05ad3Ded6fcc510324Af8e2631717af6dA5C8B5B,
      0x32D619Dc6188409CebbC52f921Ab306F07DB085b,
      0x210744C64Eea863Cf0f972e5AEBC683b98fB1984,
      0xedCafC4Ad8097c2012980A2a7087d74B86bDDAf9,
      0xFc3e31519B551bd594235dd0eF014375a87C4e21,
      0x6aaABf51C5F6D2D93212Cf7DAD73D67AFa0148d0,
      0x22C23429e46e7944D2918F2B368b799b11C417C1,
      0x03A7B98C226225e330d11D1B9177891391Fa4f80,
      0x20238eB5643d4D7b7Ab3C30f3bf7B8E2B85cA1e7,
      0x07d28F88D677C4056EA6722aa35d92903b2a63da,
      0x262B9fcfe8CFA900aF4D1f5c20396E969B9655DD
    ];

    CandidateProfile storage _profile;
    for (uint i; i < consensusList.length; i++) {
      _profile = _id2Profile[consensusList[i]];
      _profile.id = consensusList[i];
    }
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
