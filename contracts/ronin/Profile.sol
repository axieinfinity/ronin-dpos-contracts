// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../extensions/collections/HasContracts.sol";
import "../interfaces/IProfile.sol";
import "../interfaces/staking/IStaking.sol";
import "../utils/RoleAccess.sol";

pragma solidity ^0.8.9;

contract Profile is IProfile, HasContracts, Initializable {
  /// @dev Mapping from id address => candidate profile.
  mapping(TPoolId => CandidateProfile) public _id2Profile;
  /// @dev Mapping from consensus address => id address.
  mapping(address => TPoolId) public _consensus2Id;

  /// @dev Event emitted when a profile with `id` is added.
  event ProfileAdded(TPoolId indexed id);

  /// @dev Error of already existed profile.
  error ErrExistentProfile();
  /// @dev Event emitted when a address in a profile is changed.
  event ProfileAddressChanged(TPoolId indexed id, RoleAccess indexed addressType);

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

  function getId2Profile(TPoolId id) external view returns (CandidateProfile memory) {
    return _id2Profile[id];
  }

  function getConsensus2Id(address consensus) external view returns (TPoolId id) {
    return _consensus2Id[consensus];
  }

  function getManyConsensus2Id(address[] calldata consensusList) external view returns (TPoolId[] memory idList) {
    idList = new TPoolId[](consensusList.length);
    unchecked {
      for (uint i; i < consensusList.length; ++i) {
        idList[i] = _consensus2Id[consensusList[i]];
      }
    }
  }

  function addNewProfile(CandidateProfile memory profile) external onlyAdmin {
    CandidateProfile storage _profile = _getId2ProfileHelper(profile.id);
    _addNewProfile(_profile, profile);
  }

  function execApplyValidatorCandidate(
    address admin,
    address consensus,
    address treasury,
    address bridgeOperator
  ) external onlyContract(ContractType.STAKING) {
    // TODO: handle previous added consensus
    TPoolId id = TPoolId.wrap(consensus);
    CandidateProfile storage _profile = _id2Profile[id];

    CandidateProfile memory mProfile = CandidateProfile({
      id: id,
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

  function _getId2ProfileHelper(TPoolId id) internal view returns (CandidateProfile storage _profile) {
    _profile = _id2Profile[id];
    if (TPoolId.unwrap(_profile.id) != address(0)) revert ErrExistentProfile();
  }

  /**
   * @dev Updated immediately without waiting time.
   *
   * Interactions:
   * - Update `PoolDetail` in {BaseStaking.sol}.
   * - Update `_adminOfActivePoolMapping` in {BaseStaking.sol}.
   *
   * Emit an {ProfileAddressChanged}.
   */
  function requestChangeAdminAddress(TPoolId id, address newAdminAddr) external {
    IStaking stakingContract = IStaking(getContract(ContractType.STAKING));
    stakingContract.execChangeAdminAddress(id, newAdminAddr);

    CandidateProfile storage _profile = _getId2ProfileHelper(id);
    _profile.admin = newAdminAddr;

    emit ProfileAddressChanged(id, RoleAccess.ADMIN);
  }

  /**
   * @dev Updated immediately without waiting time. (???)
   *
   * Interactions:
   * - Update in Bridge contract for Validator address mapping.
   * - Update in BridgeTracking for tracking their votes.
   * - Update in Validator contract for BridgeOperator address mapping.
   * - Update in Validator contract for bridge's reward. (???)
   *
   * Emit an {ProfileAddressChanged}.
   */
  function requestChangeBridgeOperator(TPoolId id, address newBridgeAddr) external {
    CandidateProfile storage _profile = _getId2ProfileHelper(id);

    _profile.bridgeOperator = newBridgeAddr;

    emit ProfileAddressChanged(id, RoleAccess.BRIDGE_OPERATOR);
  }

  /**
   * @dev Updated immediately without waiting time. (???)
   *
   * Interactions:
   * - Update in Staking contract for Consensus address mapping:
   *   + Keep the same previous pool address
   *   +
   * - Update in Validator contract for:
   *   + Consensus Address mapping
   *   + Bridge Address mapping
   *   + Jail mapping
   *   + Pending reward mapping
   *   + Schedule mapping
   * - Update in Proposal contract for:
   *   + Refund of emergency exit mapping
   *   + ...
   *
   * Emit an {ProfileAddressChanged}.
   *
   */
  function requestChangeConsensusAddr(TPoolId id, address newConsensusAddr) external {
    CandidateProfile storage _profile = _getId2ProfileHelper(id);

    _profile.consensus = newConsensusAddr;

    emit ProfileAddressChanged(id, RoleAccess.CONSENSUS);
  }
}
