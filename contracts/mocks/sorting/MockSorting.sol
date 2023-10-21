// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "../libraries/Sorting.sol";

contract MockSorting {
  uint256[] public data;

  function addData(uint256[] memory _data) public {
    for (uint256 i; i < _data.length; i++) {
      data.push(_data[i]);
    }
  }

  function sort(uint256[] memory _data) public pure returns (uint256[] memory) {
    return Sorting.sort(_data);
  }

  function sortOnStorage() public returns (uint256[] memory, uint256) {
    uint256[] memory _tmpData = data;
    data = Sorting.sort(_tmpData);

    return (data, data.length);
  }

  function sortAddressesAndValues(
    address[] calldata _addrs,
    uint256[] calldata _values
  ) public pure returns (address[] memory) {
    return Sorting.sort(_addrs, _values);
  }
}
