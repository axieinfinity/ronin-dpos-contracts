// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IScript } from "./IScript.sol";
import { ContractKey } from "../configs/ContractConfig.sol";

interface IDeployScript is IScript {
  function run() external returns (address payable);

  function overrideArgs(bytes calldata args) external returns (IDeployScript);
}
