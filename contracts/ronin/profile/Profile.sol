// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../interfaces/staking/IStaking.sol";
import "../../interfaces/IProfile.sol";
import "./ProfileXComponents.sol";
import "./ProfileStorage.sol";

pragma solidity ^0.8.9;

contract Profile is IProfile, ProfileStorage, ProfileXComponents, Initializable {
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
   * @inheritdoc IProfile
   */
  function getId2Profile(address id) external view returns (CandidateProfile memory) {
    return _id2Profile[id];
  }

  /**
   * @inheritdoc IProfile
   */
  function getConsensus2Id(TConsensus consensus) external view returns (address id) {
    return _consensus2Id[consensus];
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
   * @dev Interactions: // TODO: remove following part when cleaning up code
   * - Update `PoolDetail` in {BaseStaking.sol}.
   * - Update `_adminOfActivePoolMapping` in {BaseStaking.sol}.
   */
  function requestChangeAdminAddress(address id, address newAdminAddr) external {
    IStaking stakingContract = IStaking(getContract(ContractType.STAKING));
    stakingContract.execChangeAdminAddress(id, newAdminAddr);

    CandidateProfile storage _profile = _getId2ProfileHelper(id);
    _profile.admin = newAdminAddr;

    emit ProfileAddressChanged(id, RoleAccess.ADMIN);
  }

  /**
   * @inheritdoc IProfile
   *
   * @dev Interactions: // TODO: remove following part when cleaning up code
   * - Update in Staking contract for Consensus address mapping:
   *   + [x] Keep the same previous pool address. // CHECKED, NO NEED ANY CHANGES
   *   +
   * - Update in Validator contract for:
   *   + [x] Consensus Address mapping
   *   + [x] Bridge Address mapping
   *   + [x] Jail mapping
   *   + [x] Pending reward mapping
   *   + [x] Schedule mapping
   * - Update in Proposal contract for:
   *   + Refund of emergency exit mapping
   *   + ...
   */
  function requestChangeConsensusAddr(address id, TConsensus newConsensusAddr) external {
    CandidateProfile storage _profile = _getId2ProfileHelper(id);

    _profile.consensus = newConsensusAddr;

    emit ProfileAddressChanged(id, RoleAccess.CONSENSUS);
  }
}
