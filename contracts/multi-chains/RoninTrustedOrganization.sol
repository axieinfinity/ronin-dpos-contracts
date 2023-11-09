// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../libraries/AddressArrayUtils.sol";
import "../interfaces/IRoninTrustedOrganization.sol";
import "../interfaces/IProfile.sol";
import "../extensions/collections/HasProxyAdmin.sol";
import "../extensions/collections/HasContracts.sol";
import "../udvts/Types.sol";

contract RoninTrustedOrganization is IRoninTrustedOrganization, HasProxyAdmin, HasContracts, Initializable {
  uint256 internal _num;
  uint256 internal _denom;
  uint256 internal _totalWeight;
  uint256 internal _nonce;

  /// @dev Mapping from consensus address => weight
  mapping(TConsensus => uint256) internal _consensusWeight;
  /// @dev Mapping from governor address => weight
  mapping(address => uint256) internal _governorWeight;
  /// @dev Mapping from bridge voter address => weight
  mapping(address => uint256) internal __deprecatedBridgeVoterWeight;

  /// @dev Mapping from consensus address => added block
  mapping(TConsensus => uint256) internal _addedBlock;

  /// @dev Consensus array
  TConsensus[] internal _consensusList;
  /// @dev Governors array
  address[] internal _governorList;
  /// @dev Bridge voters array
  address[] internal __deprecatedBridgeVoterList;

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(TrustedOrganization[] calldata trustedOrgs, uint256 num, uint256 denom) external initializer {
    if (trustedOrgs.length > 0) {
      _addTrustedOrganizations(trustedOrgs);
    }
    _setThreshold(num, denom);
  }

  function initializeV2(address profileContract) external reinitializer(2) {
    _setContract(ContractType.PROFILE, profileContract);
    for (uint i; i < __deprecatedBridgeVoterList.length; ++i) {
      delete __deprecatedBridgeVoterWeight[__deprecatedBridgeVoterList[i]];
    }
    delete __deprecatedBridgeVoterList;
  }

  /**
   * @inheritdoc IQuorum
   */
  function getThreshold() external view virtual returns (uint256 num_, uint256 denom_) {
    return (_num, _denom);
  }

  /**
   * @inheritdoc IQuorum
   */
  function checkThreshold(uint256 _voteWeight) external view virtual returns (bool) {
    return _voteWeight * _denom >= _num * _totalWeight;
  }

  /**
   * @inheritdoc IQuorum
   */
  function minimumVoteWeight() external view virtual returns (uint256) {
    return (_num * _totalWeight + _denom - 1) / _denom;
  }

  /**
   * @inheritdoc IQuorum
   */
  function setThreshold(
    uint256 _numerator,
    uint256 _denominator
  ) external override onlyAdmin returns (uint256, uint256) {
    return _setThreshold(_numerator, _denominator);
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function addTrustedOrganizations(TrustedOrganization[] calldata _list) external override onlyAdmin {
    _addTrustedOrganizations(_list);
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function updateTrustedOrganizations(TrustedOrganization[] calldata _list) external override onlyAdmin {
    if (_list.length == 0) revert ErrEmptyArray();
    for (uint256 _i; _i < _list.length; ) {
      _updateTrustedOrganization(_list[_i]);

      unchecked {
        ++_i;
      }
    }
    emit TrustedOrganizationsUpdated(_list);
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function removeTrustedOrganizations(TConsensus[] calldata list) external override onlyAdmin {
    if (list.length == 0) revert ErrEmptyArray();

    for (uint _i = 0; _i < list.length; ) {
      _removeTrustedOrganization(list[_i]);

      unchecked {
        ++_i;
      }
    }
    emit TrustedOrganizationsRemoved(list);
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function totalWeight() external view virtual returns (uint256) {
    return _totalWeight;
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function getConsensusWeight(TConsensus consensusAddr) external view returns (uint256) {
    return _getConsensusWeightByConsensus(consensusAddr);
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function getConsensusWeightById(address cid) external view returns (uint256) {
    return _getConsensusWeightByConsensus(__cid2css(cid));
  }

  function _getConsensusWeightByConsensus(TConsensus consensusAddr) internal view returns (uint256) {
    return _consensusWeight[consensusAddr];
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function getGovernorWeight(address _governor) external view returns (uint256) {
    return _governorWeight[_governor];
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function getConsensusWeights(TConsensus[] calldata list) external view returns (uint256[] memory) {
    return _getManyConsensusWeightsByConsensus(list);
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function getManyConsensusWeightsById(address[] calldata cids) external view returns (uint256[] memory) {
    TConsensus[] memory consensusList = __cid2cssBatch(cids);
    return _getManyConsensusWeightsByConsensus(consensusList);
  }

  function _getManyConsensusWeightsByConsensus(TConsensus[] memory list) internal view returns (uint256[] memory res) {
    res = new uint256[](list.length);
    for (uint i = 0; i < res.length; ++i) {
      res[i] = _getConsensusWeightByConsensus(list[i]);
    }
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function getGovernorWeights(address[] calldata _list) external view returns (uint256[] memory _res) {
    _res = new uint256[](_list.length);
    for (uint _i = 0; _i < _res.length; ) {
      _res[_i] = _governorWeight[_list[_i]];

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function sumConsensusWeight(TConsensus[] calldata _list) external view returns (uint256 _res) {
    for (uint _i = 0; _i < _list.length; ) {
      _res += _consensusWeight[_list[_i]];

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function sumGovernorWeight(address[] calldata _list) external view returns (uint256 _res) {
    for (uint _i = 0; _i < _list.length; ) {
      _res += _governorWeight[_list[_i]];

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function countTrustedOrganization() external view override returns (uint256) {
    return _consensusList.length;
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function getAllTrustedOrganizations() external view override returns (TrustedOrganization[] memory list) {
    list = new TrustedOrganization[](_consensusList.length);
    TConsensus consensus;
    for (uint256 _i; _i < list.length; ) {
      consensus = _consensusList[_i];
      list[_i].consensusAddr = consensus;
      list[_i].governor = _governorList[_i];
      list[_i].__deprecatedBridgeVoter = address(0);
      list[_i].weight = _consensusWeight[consensus];

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function getTrustedOrganization(TConsensus _consensusAddr) external view returns (TrustedOrganization memory trustedOrg) {
    for (uint i = 0; i < _consensusList.length; ++i) {
      if (_consensusList[i] == _consensusAddr) {
        return getTrustedOrganizationAt(i);
      }
    }
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function getTrustedOrganizationAt(uint256 _idx) public view override returns (TrustedOrganization memory) {
    TConsensus consensus = _consensusList[_idx];
    return
      TrustedOrganization(
        consensus,
        _governorList[_idx],
        address(0),
        _consensusWeight[consensus],
        _addedBlock[consensus]
      );
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function execChangeConsensusAddressForTrustedOrg(
    TConsensus oldAddr,
    TConsensus newAddr
  ) external override onlyContract(ContractType.PROFILE) {
    uint256 index = _findTrustedOrgIndexByConsensus(oldAddr);
    _consensusList[index] = newAddr;
    _consensusWeight[newAddr] = _consensusWeight[oldAddr];
    _addedBlock[newAddr] = block.number;

    _deleteConsensusInMappings(oldAddr);

    emit ConsensusAddressOfTrustedOrgChanged(getTrustedOrganizationAt(index), oldAddr);
  }

  /**
   * @dev Adds a list of trusted organizations.
   */
  function _addTrustedOrganizations(TrustedOrganization[] calldata _list) internal virtual {
    for (uint256 _i; _i < _list.length; ) {
      _addTrustedOrganization(_list[_i]);

      unchecked {
        ++_i;
      }
    }
    emit TrustedOrganizationsAdded(_list);
  }

  /**
   * @dev Adds a trusted organization.
   *
   * Requirements:
   * - The weight is larger than 0.
   * - The consensus address is not added.
   * - The governor address is not added.
   * - The bridge voter address is not added.
   *
   */
  function _addTrustedOrganization(TrustedOrganization memory _v) internal virtual {
    if (_v.addedBlock != 0) revert ErrInvalidRequest();
    _sanityCheckTrustedOrganizationData(_v);

    if (_consensusWeight[_v.consensusAddr] > 0) revert ErrConsensusAddressIsAlreadyAdded(_v.consensusAddr);

    if (_governorWeight[_v.governor] > 0) revert ErrGovernorAddressIsAlreadyAdded(_v.governor);

    _consensusList.push(_v.consensusAddr);
    _consensusWeight[_v.consensusAddr] = _v.weight;

    _governorList.push(_v.governor);
    _governorWeight[_v.governor] = _v.weight;

    _addedBlock[_v.consensusAddr] = block.number;

    _totalWeight += _v.weight;
  }

  /**
   * @dev Updates info of an existing trusted org.
   * Replace the governor address if they are different, set all weights to the new weight.
   *
   * Requirements:
   * - The weight is larger than 0.
   * - The consensus address is already added.
   *
   */
  function _updateTrustedOrganization(TrustedOrganization memory _v) internal virtual {
    _sanityCheckTrustedOrganizationData(_v);

    uint256 _weight = _consensusWeight[_v.consensusAddr];
    if (_weight == 0) revert ErrConsensusAddressIsNotAdded(_v.consensusAddr);

    uint256 _count = _consensusList.length;
    for (uint256 _i = 0; _i < _count; ) {
      if (_consensusList[_i] == _v.consensusAddr) {
        _totalWeight -= _weight;
        _totalWeight += _v.weight;

        // Replace governor address
        if (_governorList[_i] != _v.governor) {
          if (_governorWeight[_v.governor] != 0) revert ErrQueryForDupplicated();

          delete _governorWeight[_governorList[_i]];
          _governorList[_i] = _v.governor;
        }

        // Add new weight for both consensus and governor address
        _consensusWeight[_v.consensusAddr] = _v.weight;
        _governorWeight[_v.governor] = _v.weight;
        return;
      }

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @dev Removes a trusted organization by consensus address.
   *
   * Requirements:
   * - The consensus address is added.
   *
   */
  function _removeTrustedOrganization(TConsensus addr) internal virtual {
    uint256 weight = _consensusWeight[addr];
    if (weight == 0) revert ErrConsensusAddressIsNotAdded(addr);

    uint256 index = _findTrustedOrgIndexByConsensus(addr);

    _totalWeight -= weight;
    _deleteConsensusInMappings(addr);

    uint256 count = _consensusList.length;
    _consensusList[index] = _consensusList[count - 1];
    _consensusList.pop();

    delete _governorWeight[_governorList[index]];
    _governorList[index] = _governorList[count - 1];
    _governorList.pop();
  }

  function _findTrustedOrgIndexByConsensus(TConsensus addr) private view returns (uint256 index) {
    uint256 count = _consensusList.length;
    for (uint256 i = 0; i < count; i++) {
      if (_consensusList[i] == addr) {
        return i;
      }
    }
  }

  function _deleteConsensusInMappings(TConsensus addr) private {
    delete _addedBlock[addr];
    delete _consensusWeight[addr];
  }

  /**
   * @dev Sets threshold and returns the old one.
   *
   * Emits the `ThresholdUpdated` event.
   *
   */
  function _setThreshold(
    uint256 _numerator,
    uint256 _denominator
  ) internal virtual returns (uint256 _previousNum, uint256 _previousDenom) {
    if (_numerator > _denominator) revert ErrInvalidThreshold(msg.sig);

    _previousNum = _num;
    _previousDenom = _denom;
    _num = _numerator;
    _denom = _denominator;
    unchecked {
      emit ThresholdUpdated(_nonce++, _numerator, _denominator, _previousNum, _previousDenom);
    }
  }

  /**
   * @dev Hook that checks trusted organization's data. Reverts if the requirements are not met.
   *
   * Requirements:
   * - The weight must be larger than 0.
   * - The consensus address, governor address, and bridge voter address are different.
   */
  function _sanityCheckTrustedOrganizationData(TrustedOrganization memory _v) private pure {
    if (_v.weight == 0) revert ErrInvalidVoteWeight(msg.sig);

    address[] memory _addresses = new address[](3);
    _addresses[0] = TConsensus.unwrap(_v.consensusAddr);
    _addresses[1] = _v.governor;
    _addresses[2] = _v.__deprecatedBridgeVoter;

    if (AddressArrayUtils.hasDuplicate(_addresses)) revert AddressArrayUtils.ErrDuplicated(msg.sig);
  }

  function __cid2css(address cid) internal view returns (TConsensus) {
    return (IProfile(getContract(ContractType.PROFILE)).getId2Profile(cid)).consensus;
  }

  function __cid2cssBatch(address[] memory cids) internal view returns (TConsensus[] memory) {
    return IProfile(getContract(ContractType.PROFILE)).getManyId2Consensus(cids);
  }
}
