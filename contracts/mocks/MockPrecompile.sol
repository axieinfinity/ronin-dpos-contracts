// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../libraries/Sorting.sol";

contract MockPrecompile {
  function sortValidators(address[] memory _validators, uint256[] memory _weights)
    external
    pure
    returns (address[] memory)
  {
    return Sorting.sort(_validators, _weights);
  }

  function validatingDoubleSignProof(
    bytes calldata, /*_header1*/
    bytes calldata /*_header2*/
  ) external pure returns (bool _validEvidence) {
    return true;
  }
}
