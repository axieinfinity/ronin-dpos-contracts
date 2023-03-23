// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPauseTarget {
  function pause() external;

  function unpause() external;

  function paused() external returns (bool);
}
