// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IBridgeAdminOperator } from "./IBridgeAdminOperator.sol";
import { IBridgeAdminProposal } from "./IBridgeAdminProposal.sol";

interface IRoninBridgeAdmin is IBridgeAdminOperator, IBridgeAdminProposal {}
