// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/IRoninTrustedOrganization.sol";
import "../extensions/collections/HasProxyAdmin.sol";

contract RoninTrustedOrganization is IRoninTrustedOrganization, HasProxyAdmin, Initializable {
  using EnumerableSet for EnumerableSet.AddressSet;

  uint256 internal _num;
  uint256 internal _denom;
  uint256 internal _totalWeights;
  uint256 internal _nonce;

  /// @dev Address set of the trusted organizations
  EnumerableSet.AddressSet internal _orgs;
  /// @dev Mapping from trusted organization address => its weight
  mapping(address => uint256) internal _weight;

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(
    WeightedAddress[] calldata _trustedOrgs,
    uint256 __num,
    uint256 __denom
  ) external initializer {
    _addTrustedOrganizations(_trustedOrgs);
    _setThreshold(__num, __denom);
  }

  /**
   * @inheritdoc IQuorum
   */
  function getThreshold() external view virtual returns (uint256, uint256) {
    return (_num, _denom);
  }

  /**
   * @inheritdoc IQuorum
   */
  function checkThreshold(uint256 _voteWeight) external view virtual returns (bool) {
    return _voteWeight * _denom >= _num * _totalWeights;
  }

  /**
   * @inheritdoc IQuorum
   */
  function minimumVoteWeight() external view virtual returns (uint256) {
    return (_num * _totalWeights + _denom - 1) / _denom;
  }

  /**
   * @inheritdoc IQuorum
   */
  function setThreshold(uint256 _numerator, uint256 _denominator)
    external
    override
    onlyAdmin
    returns (uint256, uint256)
  {
    return _setThreshold(_numerator, _denominator);
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function addTrustedOrganizations(WeightedAddress[] calldata _list) external override onlyAdmin {
    _addTrustedOrganizations(_list);
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function updateTrustedOrganizations(WeightedAddress[] calldata _list) external override onlyAdmin {
    WeightedAddress memory _item;
    for (uint _i = 0; _i < _list.length; _i++) {
      _item = _list[_i];

      if (_orgs.contains(_item.addr) && _item.weight > 0) {
        _totalWeights -= _weight[_item.addr];
        _totalWeights += _item.weight;
        _weight[_item.addr] = _item.weight;
        emit TrustedOrganizationUpdated(_item);
      }
    }
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function removeTrustedOrganizations(address[] calldata _list) external override onlyAdmin {
    for (uint _i = 0; _i < _list.length; _i++) {
      if (_orgs.remove(_list[_i])) {
        _totalWeights -= _weight[_list[_i]];
        delete _weight[_list[_i]];
        emit TrustedOrganizationRemoved(_list[_i]);
      }
    }
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function totalWeights() external view virtual returns (uint256) {
    return _totalWeights;
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function getWeight(address _addr) external view override returns (uint256) {
    return _weight[_addr];
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function getWeights(address[] calldata _list) external view override returns (uint256[] memory _res) {
    _res = new uint256[](_list.length);
    for (uint _i = 0; _i < _res.length; _i++) {
      _res[_i] = _weight[_list[_i]];
    }
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function sumWeights(address[] calldata _list) external view override returns (uint256 _res) {
    for (uint _i = 0; _i < _list.length; _i++) {
      _res += _weight[_list[_i]];
    }
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function getTrustedOrganizationAt(uint256 _idx) external view override returns (WeightedAddress memory _res) {
    _res.addr = _orgs.at(_idx);
    _res.weight = _weight[_res.addr];
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function countTrustedOrganizations() external view override returns (uint256) {
    return _orgs.length();
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function getAllTrustedOrganizations() external view override returns (WeightedAddress[] memory _res) {
    address[] memory _list = _orgs.values();
    _res = new WeightedAddress[](_list.length);
    for (uint _i = 0; _i < _res.length; _i++) {
      _res[_i].addr = _list[_i];
      _res[_i].weight = _weight[_list[_i]];
    }
  }

  /**
   * @dev Adds a list of addresses into the trusted organization.
   */
  function _addTrustedOrganizations(WeightedAddress[] calldata _list) internal {
    for (uint _i = 0; _i < _list.length; _i++) {
      if (_orgs.add(_list[_i].addr) && _list[_i].weight > 0) {
        _totalWeights += _list[_i].weight;
        _weight[_list[_i].addr] = _list[_i].weight;
        emit TrustedOrganizationAdded(_list[_i]);
      }
    }
  }

  /**
   * @dev Sets threshold and returns the old one.
   *
   * Emits the `ThresholdUpdated` event.
   *
   */
  function _setThreshold(uint256 _numerator, uint256 _denominator)
    internal
    virtual
    returns (uint256 _previousNum, uint256 _previousDenom)
  {
    require(_numerator <= _denominator, "RoninTrustedOrganization: invalid threshold");
    _previousNum = _num;
    _previousDenom = _denom;
    _num = _numerator;
    _denom = _denominator;
    emit ThresholdUpdated(_nonce++, _numerator, _denominator, _previousNum, _previousDenom);
  }
}
