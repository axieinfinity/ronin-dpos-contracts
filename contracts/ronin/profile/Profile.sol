// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
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
    require(block.chainid != 2021, "mismatch chainID");
    require(msg.sender != 0x968D0Cd7343f711216817E617d3f92a23dC91c07, "not testnet admin");

    CandidateProfile storage _profile;

    {
      _profile = _getId2ProfileHelper(0xCaba9D9424D6bAD99CE352A943F59279B533417a);
      _setConsensus(_profile, 0xCaba9D9424D6bAD99CE352A943F59279B533417a);
      _setAdmin(_profile, 0x29E8428cA857feA6C419a7193d475f8b06712126);
      _setTreasury(_profile, payable(0x29E8428cA857feA6C419a7193d475f8b06712126));
      _setGovernor(_profile, 0xb033ba62EC622dC54D0ABFE0254e79692147CA26);
    }
    {
      _profile = _getId2ProfileHelper(0x9f1Abc67beA4db5560371fF3089F4Bfe934c36Bc);
      _setConsensus(_profile, 0x9f1Abc67beA4db5560371fF3089F4Bfe934c36Bc);
      _setAdmin(_profile, 0x8c909167D0BC6d7aa9066Cc683b2fb8C1e2111B9);
      _setTreasury(_profile, payable(0x8c909167D0BC6d7aa9066Cc683b2fb8C1e2111B9));
      _setGovernor(_profile, 0x087D08e3ba42e64E3948962dd1371F906D1278b9);
    }
    {
      _profile = _getId2ProfileHelper(0xA85ddDdCeEaB43DccAa259dd4936aC104386F9aa);
      _setConsensus(_profile, 0xA85ddDdCeEaB43DccAa259dd4936aC104386F9aa);
      _setAdmin(_profile, 0x57832A94810E18c84a5A5E2c4dD67D012ade574F);
      _setTreasury(_profile, payable(0x57832A94810E18c84a5A5E2c4dD67D012ade574F));
      _setGovernor(_profile, 0x52ec2e6BBcE45AfFF8955Da6410bb13812F4289F);
    }
    {
      _profile = _getId2ProfileHelper(0xAcf8Bf98D1632e602d0B1761771049aF21dd6597);
      _setConsensus(_profile, 0xAcf8Bf98D1632e602d0B1761771049aF21dd6597);
      _setAdmin(_profile, 0xe0486a7D685C3Fa07CC5A42F6a0dFfBb3aa6BE57);
      _setTreasury(_profile, payable(0xe0486a7D685C3Fa07CC5A42F6a0dFfBb3aa6BE57));
      _setGovernor(_profile, 0xd24D87DDc1917165435b306aAC68D99e0F49A3Fa);
    }
    {
      _profile = _getId2ProfileHelper(0xE9bf2A788C27dADc6B169d52408b710d267b9bff);
      _setConsensus(_profile, 0xE9bf2A788C27dADc6B169d52408b710d267b9bff);
      _setAdmin(_profile, 0x9BC9A6086Df4be878bE1AB6241C80c604B935b98);
      _setTreasury(_profile, payable(0x9BC9A6086Df4be878bE1AB6241C80c604B935b98));
    }
    {
      _profile = _getId2ProfileHelper(0xD086D2e3Fac052A3f695a4e8905Ce1722531163C);
      _setConsensus(_profile, 0xD086D2e3Fac052A3f695a4e8905Ce1722531163C);
      _setAdmin(_profile, 0x1b3cBDEE074bb4C939c68c4b0a88E036a32AAF25);
      _setTreasury(_profile, payable(0x1b3cBDEE074bb4C939c68c4b0a88E036a32AAF25));
    }
    {
      _profile = _getId2ProfileHelper(0x9687e8C41fa369aD08FD278a43114C4207856a61);
      _setConsensus(_profile, 0x9687e8C41fa369aD08FD278a43114C4207856a61);
      _setAdmin(_profile, 0xcF0E23AED16D5d971910e748ACd48849E4b7239C);
      _setTreasury(_profile, payable(0xcF0E23AED16D5d971910e748ACd48849E4b7239C));
    }
    {
      _profile = _getId2ProfileHelper(0xa325Fd3a2f4f5CafE2c151eE428b5CeDeD628193);
      _setConsensus(_profile, 0xa325Fd3a2f4f5CafE2c151eE428b5CeDeD628193);
      _setAdmin(_profile, 0x5b13EeA524729c568bE82dD6af0522c27Fd9253e);
      _setTreasury(_profile, payable(0x5b13EeA524729c568bE82dD6af0522c27Fd9253e));
    }
    {
      _profile = _getId2ProfileHelper(0x9422d990AcDc3f2b3AA3B97303aD3060F09d7ffC);
      _setConsensus(_profile, 0x9422d990AcDc3f2b3AA3B97303aD3060F09d7ffC);
      _setAdmin(_profile, 0x24711329e21E0b29d7eb3560C997E5D175589101);
      _setTreasury(_profile, payable(0x24711329e21E0b29d7eb3560C997E5D175589101));
    }
    {
      _profile = _getId2ProfileHelper(0xc3C97512421BF3e339E9fd412f18584e53138bFA);
      _setConsensus(_profile, 0xc3C97512421BF3e339E9fd412f18584e53138bFA);
      _setAdmin(_profile, 0x87fab89D2ef34569E96332673233f2012495900E);
      _setTreasury(_profile, payable(0x87fab89D2ef34569E96332673233f2012495900E));
    }

    {
      _profile = _getId2ProfileHelper(0x78fD38faa30ea66702cc39383D2E84f9a4A56fA6);
      _setConsensus(_profile, 0x78fD38faa30ea66702cc39383D2E84f9a4A56fA6);
      _setAdmin(_profile, 0x1C70B8160E92D56E550caf02e1f2e5EC0Fdb551A);
      _setTreasury(_profile, payable(0x1C70B8160E92D56E550caf02e1f2e5EC0Fdb551A));
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
