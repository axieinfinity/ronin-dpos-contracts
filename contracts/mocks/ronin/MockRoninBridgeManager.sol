// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { RoninBridgeManager } from "../../ronin/gateway/RoninBridgeManager.sol";
import { GlobalProposal } from "../../extensions/sequential-governance/governance-proposal/GovernanceProposal.sol";

contract MockRoninBridgeManager is RoninBridgeManager {
  constructor(
    uint256 num,
    uint256 denom,
    uint256 roninChainId,
    uint256 expiryDuration,
    address bridgeContract,
    address[] memory callbackRegisters,
    address[] memory bridgeOperators,
    address[] memory governors,
    uint96[] memory voteWeights,
    GlobalProposal.TargetOption[] memory targetOptions,
    address[] memory targets
  )
    RoninBridgeManager(
      num,
      denom,
      roninChainId,
      expiryDuration,
      bridgeContract,
      callbackRegisters,
      bridgeOperators,
      governors,
      voteWeights,
      targetOptions,
      targets
    )
  {}
}
