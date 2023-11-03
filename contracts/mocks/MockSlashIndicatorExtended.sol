// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./MockPrecompile.sol";
import "../ronin/slash-indicator/SlashIndicator.sol";
import "../interfaces/validator/IRoninValidatorSet.sol";

contract MockSlashIndicatorExtended is SlashIndicator, MockPrecompile {
  function _pcValidateEvidence(
    address _consensusAddr,
    bytes calldata _header1,
    bytes calldata _header2
  ) internal pure override returns (bool _validEvidence) {
    return validatingDoubleSignProof(_consensusAddr, _header1, _header2);
  }
}
