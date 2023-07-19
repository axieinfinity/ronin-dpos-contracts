// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IBridgeReward, BridgeReward } from "../../ronin/gateway/BridgeReward.sol";

contract MockBridgeReward is BridgeReward {
  function calcRewardAndCheckSlashedStatus(
    bool isValidTrackingResponse,
    uint256 numBridgeOperators,
    uint256 rewardPerPeriod,
    uint256 ballot,
    uint256 totalBallots,
    uint256 period,
    uint256 slashUntilPeriod
  ) external pure returns (uint256 reward, bool isSlashed) {
    return
      _calcRewardAndCheckSlashedStatus(
        isValidTrackingResponse,
        numBridgeOperators,
        rewardPerPeriod,
        ballot,
        totalBallots,
        period,
        slashUntilPeriod
      );
  }

  function calcReward(
    bool isValidTrackingResponse,
    uint256 numBridgeOperators,
    uint256 rewardPerPeriod,
    uint256 ballot,
    uint256 totalBallots
  ) external pure returns (uint256 reward) {
    reward = _calcReward(isValidTrackingResponse, numBridgeOperators, rewardPerPeriod, ballot, totalBallots);
  }

  function isValidBridgeTrackingResponse(
    uint256 totalBallots,
    uint256 totalVotes,
    uint256[] memory ballots
  ) external pure returns (bool valid) {
    return _isValidBridgeTrackingResponse(totalBallots, totalVotes, ballots);
  }

  function isSharingRewardEqually(
    uint256 totalBallots,
    uint256 totalVotes,
    uint256[] memory ballots
  ) external returns (bool shareEqually) {
    return _isSharingRewardEqually(totalBallots, totalVotes, ballots);
  }

  function isSlashedThisPeriod(uint256 period, uint256 slashUntilDuration) external pure returns (bool) {
    return _isSlashedThisPeriod(period, slashUntilDuration);
  }
}
