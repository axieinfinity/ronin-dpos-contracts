// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../SlashIndicator.sol";

contract MockSlashIndicatorExtended is SlashIndicator {
  function slashFelony(address _validatorAddr) external {
    _validatorContract.slash(_validatorAddr, 0, 0);
  }

  function slashMisdemeanor(address _validatorAddr) external {
    _validatorContract.slash(_validatorAddr, 0, 0);
  }

  function _validateEvidence(
    BlockHeader memory, /*_header1*/
    BlockHeader memory /*_header2*/
  ) internal pure override returns (bool _validEvidence) {
    return true;
  }
}
