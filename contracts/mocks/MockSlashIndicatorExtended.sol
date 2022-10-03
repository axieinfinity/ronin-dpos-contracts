// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../SlashIndicator.sol";

contract MockSlashIndicatorExtended is SlashIndicator {
  function _validateEvidence(
    BlockHeader memory, /*_header1*/
    BlockHeader memory /*_header2*/
  ) internal pure override returns (bool _validEvidence) {
    return true;
  }
}
