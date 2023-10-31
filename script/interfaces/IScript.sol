// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IScript {
  function run(string calldata command) external;
}
