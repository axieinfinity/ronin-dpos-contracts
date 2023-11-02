// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../interfaces/validator/ICandidateManager.sol";
import "../../interfaces/validator/IRoninValidatorSet.sol";
import "../../interfaces/staking/IStaking.sol";
import "../../interfaces/IProfile.sol";
import "./ProfileXComponents.sol";
import { ErrUnauthorized, RoleAccess } from "../../utils/CommonErrors.sol";
import { ContractType } from "../../utils/ContractType.sol";

pragma solidity ^0.8.9;

contract Profile is IProfile, ProfileXComponents, Initializable {
  constructor() {
    _disableInitializers();
  }

  function initialize(address validatorContract) external initializer {
    _setContract(ContractType.VALIDATOR, validatorContract);
  }

  function initializeV2(address stakingContract) external reinitializer(2) {
    _setContract(ContractType.STAKING, stakingContract);
  }

  function initializeV3() external reinitializer(3) {
    address[] memory validatorCandidates = IRoninValidatorSet(getContract(ContractType.VALIDATOR))
      .getValidatorCandidates();
    TConsensus[] memory consensuses;
    assembly ("memory-safe") {
      consensuses := validatorCandidates
    }
    for (uint256 i; i < validatorCandidates.length; ++i) {
      _consensus2Id[consensuses[i]] = validatorCandidates[i];
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
  function getConsensus2Id(TConsensus consensus) external view returns (address id) {
    id = _consensus2Id[consensus];
  }

  /**
   * @inheritdoc IProfile
   */
  function getManyConsensus2Id(TConsensus[] calldata consensusList) external view returns (address[] memory idList) {
    idList = new address[](consensusList.length);
    unchecked {
      for (uint i; i < consensusList.length; ++i) {
        idList[i] = _consensus2Id[consensusList[i]];
      }
    }
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
   *
   * @dev Side-effects on other contracts:
   * - Update Staking contract:
   *    + Update (id => PoolDetail) mapping in {BaseStaking.sol}.
   *    + Update `_adminOfActivePoolMapping` in {BaseStaking.sol}.
   * - Update Validator contract:
   *    + Update (id => ValidatorCandidate) mapping
   */
  function requestChangeAdminAddress(address id, address newAdminAddr) external {
    CandidateProfile storage _profile = _getId2ProfileHelper(id);
    _requireCandidateAdmin(_profile);
    _checkNonZeroAndNonDuplicated(RoleAccess.ADMIN, newAdminAddr);
    _setAdmin(_profile, newAdminAddr);

    IStaking stakingContract = IStaking(getContract(ContractType.STAKING));
    IRoninValidatorSet validatorContract = IRoninValidatorSet(getContract(ContractType.VALIDATOR));
    stakingContract.execChangeAdminAddress(id, newAdminAddr);
    validatorContract.execChangeAdminAddress(id, newAdminAddr);

    emit ProfileAddressChanged(id, RoleAccess.ADMIN);
  }

  /**
   * @inheritdoc IProfile
   *
   * @dev Side-effects on other contracts:
   * - Update in Staking contract for Consensus address mapping:
   *   + [x] Keep the same previous pool address.
   *   +
   * - Update in Validator contract for:
   *   + [x] Consensus Address mapping
   *   + [x] Bridge Address mapping
   *   + [x] Jail mapping
   *   + [x] Pending reward mapping
   *   + [x] Schedule mapping
   * - Update in Slashing contract for:
   *   + [x] Handling slash indicator
   *   + [x] Handling slash fast finality
   *   + [x] Handling slash double sign
   * - Update in Proposal contract for:
   *   + Refund of emergency exit mapping
   *   + ...
   */
  function requestChangeConsensusAddr(address id, TConsensus newConsensusAddr) external {
    CandidateProfile storage _profile = _getId2ProfileHelper(id);
    _requireCandidateAdmin(_profile);
    _checkNonZeroAndNonDuplicated(RoleAccess.CONSENSUS, TConsensus.unwrap(newConsensusAddr));
    _setConsensus(_profile, newConsensusAddr);

    IRoninValidatorSet validatorContract = IRoninValidatorSet(getContract(ContractType.VALIDATOR));
    validatorContract.execChangeConsensusAddress(id, newConsensusAddr);

    emit ProfileAddressChanged(id, RoleAccess.CONSENSUS);
  }

  /**
   * @inheritdoc IProfile
   *
   * @dev Side-effects on other contracts:
   * - Update Validator contract:
   *    + Update (id => ValidatorCandidate) mapping
   */
  function requestChangeTreasuryAddr(address id, address payable newTreasury) external {
    CandidateProfile storage _profile = _getId2ProfileHelper(id);
    _requireCandidateAdmin(_profile);
    _checkNonZeroAndNonDuplicated(RoleAccess.TREASURY, newTreasury);
    _setTreasury(_profile, newTreasury);

    IRoninValidatorSet validatorContract = IRoninValidatorSet(getContract(ContractType.VALIDATOR));
    validatorContract.execChangeTreasuryAddress(id, newTreasury);

    emit ProfileAddressChanged(id, RoleAccess.TREASURY);
  }

  /**
   * @inheritdoc IProfile
   */
  function changePubkey(address id, bytes memory pubkey) external {
    CandidateProfile storage _profile = _getId2ProfileHelper(id);
    _requireCandidateAdmin(_profile);
    _checkNonDuplicatedPubkey(pubkey);
    _setPubkey(_profile, pubkey);

    emit PubkeyChanged(id, pubkey);
  }

  function _requireCandidateAdmin(CandidateProfile storage sProfile) internal view {
    if (
      msg.sender != sProfile.admin ||
      !IRoninValidatorSet(getContract(ContractType.VALIDATOR)).isCandidateAdmin(sProfile.consensus, msg.sender)
    ) revert ErrUnauthorized(msg.sig, RoleAccess.ADMIN);
  }
}
