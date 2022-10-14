// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../libraries/Sorting.sol";

contract PrecompileSortValidators {
  function sortValidators(address[] memory _validators, uint256[] memory _weights)
    external
    pure
    returns (address[] memory)
  {
    return Sorting.sort(_validators, _weights);
  }
}
