// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IBridgeManager } from "./bridge/IBridgeManager.sol";
import { IBridgeAdminProposal } from "./IBridgeAdminProposal.sol";

interface IMainchainBridgeManager is IBridgeManager, IBridgeAdminProposal {}
