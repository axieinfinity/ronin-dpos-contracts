// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/IRoninTrustedOrganization.sol";
import "../extensions/HasProxyAdmin.sol";

contract RoninTrustedOrganization is IRoninTrustedOrganization, HasProxyAdmin, Initializable {
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet internal _orgs;

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(address[] calldata _trustedOrgs) external initializer {
    _addTrustedOrganizations(_trustedOrgs);
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function addTrustedOrganizations(address[] calldata _list) external override onlyAdmin {
    _addTrustedOrganizations(_list);
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function removeTrustedOrganizations(address[] calldata _list) external override onlyAdmin {
    if (_list.length == 0) {
      return;
    }

    for (uint _i = 0; _i < _list.length; _i++) {
      if (_orgs.remove(_list[_i])) {
        emit TrustedOrganizationRemoved(_list[_i]);
      }
    }
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function isTrustedOrganizations(address[] calldata _list) external view override returns (bool[] memory _res) {
    _res = new bool[](_list.length);
    for (uint _i = 0; _i < _res.length; _i++) {
      _res[_i] = _orgs.contains(_list[_i]);
    }
  }

  /**
   * @inheritdoc IRoninTrustedOrganization
   */
  function getTrustedOrganizationAt(uint256 _idx) external view override returns (address) {
    return _orgs.at(_idx);
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
  function getAllTrustedOrganizations() external view override returns (address[] memory) {
    return _orgs.values();
  }

  /**
   * @dev Adds a list of addresses into the trusted organization.
   */
  function _addTrustedOrganizations(address[] calldata _list) internal {
    if (_list.length == 0) {
      return;
    }

    for (uint _i = 0; _i < _list.length; _i++) {
      if (_orgs.add(_list[_i])) {
        emit TrustedOrganizationAdded(_list[_i]);
      }
    }
  }
}
