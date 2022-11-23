// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IJailingInfo.sol";
import "./ITimingInfo.sol";
import "./IValidatorInfo.sol";

interface ICommonInfo is ITimingInfo, IJailingInfo, IValidatorInfo {
  /// @dev Emitted when the deprecated reward is withdrawn.
  event DeprecatedRewardWithdrawn(address indexed recipientAddr, uint256 amount);

  /**
   * @dev Returns the total deprecated reward, which includes reward that is not sent for slashed validators and unsastified bridge operators
   */
  function totalDeprecatedReward() external view returns (uint256);
}
