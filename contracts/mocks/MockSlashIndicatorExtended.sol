// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../slash/SlashIndicator.sol";
import "hardhat/console.sol";

contract MockSlashIndicatorExtended is SlashIndicator {
  function _validateEvidence(
    BlockHeader memory, /*_header1*/
    BlockHeader memory /*_header2*/
  ) internal view override returns (bool _validEvidence) {
    return true;
  }
}
