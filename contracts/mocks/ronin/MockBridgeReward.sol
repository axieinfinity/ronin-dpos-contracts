// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IBridgeReward, BridgeReward } from "../../ronin/gateway/BridgeReward.sol";

contract MockBridgeReward is BridgeReward {
  function calcRewardAndCheckSlashedStatus(
    bool isValidTrackingResponse,
    uint256 numBridgeOperators,
    uint256 rewardPerPeriod,
    uint256 ballot,
    uint256 totalBallot,
    uint256 period,
    uint256 slashUntilPeriod
  ) external pure returns (uint256 reward, bool isSlashed) {
    return
      _calcRewardAndCheckSlashedStatus(
        isValidTrackingResponse,
        numBridgeOperators,
        rewardPerPeriod,
        ballot,
        totalBallot,
        period,
        slashUntilPeriod
      );
  }

  function calcReward(
    bool isValidTrackingResponse,
    uint256 numBridgeOperators,
    uint256 rewardPerPeriod,
    uint256 ballot,
    uint256 totalBallot
  ) external pure returns (uint256 reward) {
    reward = _calcReward(isValidTrackingResponse, numBridgeOperators, rewardPerPeriod, ballot, totalBallot);
  }

  function isValidBridgeTrackingResponse(
    uint256 totalBallot,
    uint256 totalVote,
    uint256[] memory ballots
  ) external pure returns (bool valid) {
    return _isValidBridgeTrackingResponse(totalBallot, totalVote, ballots);
  }

  function shouldShareEqually(
    uint256 totalBallot,
    uint256 totalVote,
    uint256[] memory ballots
  ) external returns (bool shareEqually) {
    return _shouldShareEqually(totalBallot, totalVote, ballots);
  }

  function shouldSlashedThisPeriod(uint256 period, uint256 slashUntilDuration) external pure returns (bool) {
    return _shouldSlashedThisPeriod(period, slashUntilDuration);
  }
}
