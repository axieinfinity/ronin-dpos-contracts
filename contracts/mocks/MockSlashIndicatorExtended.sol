// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./MockPrecompile.sol";
import "../ronin/SlashIndicator.sol";

contract MockSlashIndicatorExtended is SlashIndicator, MockPrecompile {
  function slashFelony(address _validatorAddr) external {
    _validatorContract.slash(_validatorAddr, 0, 0);
  }

  function slashMisdemeanor(address _validatorAddr) external {
    _validatorContract.slash(_validatorAddr, 0, 0);
  }

  function _pcValidateEvidence(bytes calldata _header1, bytes calldata _header2)
    internal
    pure
    override
    returns (bool _validEvidence)
  {
    return validatingDoubleSignProof(_header1, _header2);
  }
}
