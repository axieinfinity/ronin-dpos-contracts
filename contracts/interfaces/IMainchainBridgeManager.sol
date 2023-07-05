// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IBridgeOperatorManager } from "./IBridgeOperatorManager.sol";
import { IBridgeAdminProposal } from "./IBridgeAdminProposal.sol";

interface IMainchainBridgeManager is IBridgeOperatorManager, IBridgeAdminProposal {}
