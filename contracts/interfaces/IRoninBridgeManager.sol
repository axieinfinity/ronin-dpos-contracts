// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IBridgeManager } from "./IBridgeManager.sol";
import { IBridgeAdminProposal } from "./IBridgeAdminProposal.sol";

interface IRoninBridgeManager is IBridgeManager, IBridgeAdminProposal {}
