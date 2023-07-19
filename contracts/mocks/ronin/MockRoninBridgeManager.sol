// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { RoninBridgeManager } from "../../ronin/gateway/RoninBridgeManager.sol";

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
    uint256[] memory voteWeights
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
      voteWeights
    )
  {}
}
