// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IJailingInfo.sol";
import "./ITimingInfo.sol";
import "./IValidatorInfo.sol";

interface ICommonInfo is ITimingInfo, IJailingInfo, IValidatorInfo {
  struct EmergencyExitInfo {
    uint256 lockedAmount;
    // The timestamp that this locked amount will be recycled to staking vesting contract
    uint256 recyclingAt;
  }

  /// @dev Emitted when the deprecated reward is withdrawn.
  event DeprecatedRewardRecycled(address indexed recipientAddr, uint256 amount);
  /// @dev Emitted when the deprecated reward withdrawal is failed
  event DeprecatedRewardRecycleFailed(address indexed recipientAddr, uint256 amount, uint256 balance);

  // Error thrown when receives RON from neither staking vesting contract nor staking contract"
  error UnauthorizedReceiveRON();

  /**
   * @dev Returns the total deprecated reward, which includes reward that is not sent for slashed validators and unsastified bridge operators
   */
  function totalDeprecatedReward() external view returns (uint256);

  /**
   * @dev Returns the emergency exit request.
   */
  function getEmergencyExitInfo(address _consensusAddr) external view returns (EmergencyExitInfo memory);
}
