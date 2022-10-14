// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

contract PrecompileValidateDoubleSign {
  function validatingDoubleSignProof(
    bytes calldata, /*_header1*/
    bytes calldata /*_header2*/
  ) external pure returns (bool _validEvidence) {
    return true;
  }
}
