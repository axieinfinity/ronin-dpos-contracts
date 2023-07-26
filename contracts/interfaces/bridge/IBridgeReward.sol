// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { IBridgeRewardEvents } from "./events/IBridgeRewardEvents.sol";

interface IBridgeReward is IBridgeRewardEvents {
  /**
   * @dev This function allows bridge operators to manually synchronize the reward for a given period length.
   * @param periodLength The length of the reward period for which synchronization is requested.
   */
  function syncReward(uint256 periodLength) external;

  /**
   * @dev Receives RON from any address.
   */
  function receiveRON() external payable;

  /**
   * @dev Invoke calculate and transfer reward to operators based on their performance.
   *
   * Requirements:
   * - This method is only called once each period.
   * - The caller must be the bridge tracking contract or a bridge operator.
   */
  function execSyncReward(
    address[] calldata operators,
    uint256[] calldata ballots,
    uint256 totalBallots,
    uint256 totalVotes,
    uint256 period
  ) external;

  /**
   * @dev Retrieve the total amount of rewards that have been topped up in the contract.
   * @return totalRewardsToppedUp The total rewards topped up value.
   */
  function getTotalRewardsToppedUp() external view returns (uint256);

  /**
   * @dev Retrieve the total amount of rewards that have been scattered to bridge operators in the contract.
   * @return totalRewardsScattered The total rewards scattered value.
   */
  function getTotalRewardsScattered() external view returns (uint256);

  /**
   * @dev Getter for all bridge operators per period.
   */
  function getRewardPerPeriod() external view returns (uint256);

  /**
   * @dev External function to retrieve the latest rewarded period in the contract.
   * @return latestRewardedPeriod The latest rewarded period value.
   */
  function getLatestRewardedPeriod() external view returns (uint256);

  /**
   * @dev Setter for all bridge operators per period.
   */
  function setRewardPerPeriod(uint256 rewardPerPeriod) external;
}
