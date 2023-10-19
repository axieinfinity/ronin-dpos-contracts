// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IBridgeReward } from "@ronin/contracts/interfaces/bridge/IBridgeReward.sol";
import { ContractType, BridgeTracking } from "@ronin/contracts/ronin/gateway/BridgeTracking.sol";
import { console2 } from "forge-std/console2.sol";

contract BridgeTrackingRecoveryLogic is BridgeTracking {
  function recoverFund() external onlyAdmin {
    IBridgeReward bridgeRewardContract = IBridgeReward(0x1C952D6717eBFd2E92E5f43Ef7C1c3f7677F007D);
    address receiver = msg.sender;

    address[] memory operators = new address[](1);
    uint256[] memory ballots = new uint256[](1);
    operators[0] = receiver;
    ballots[0] = 1;
    uint256 period = bridgeRewardContract.getLatestRewardedPeriod() + 1;
    uint256 count;
    while (address(bridgeRewardContract).balance > 1 ether) {
      bridgeRewardContract.execSyncReward(operators, ballots, 1, 1, period);
      period++;
      ++count;
    }

    console2.log("total tx:", count);
  }
}
