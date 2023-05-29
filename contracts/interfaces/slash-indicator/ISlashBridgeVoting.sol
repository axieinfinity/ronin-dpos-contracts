// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IBaseSlash.sol";

interface ISlashBridgeVoting is IBaseSlash {
  /**
   * @dev Error thrown when an invalid slash is encountered.
   */
  error ErrInvalidSlash();

  /**
   * @dev Emitted when the configs to slash bridge voting is updated. See the method `getBridgeVotingSlashingConfigs` for param
   * details.
   */
  event BridgeVotingSlashingConfigsUpdated(uint256 bridgeVotingThreshold, uint256 bridgeVotingSlashAmount);

  /**
   * @dev Slashes for bridge voter governance.
   *
   * Emits the event `Slashed`.
   */
  function slashBridgeVoting(address _consensusAddr) external;

  /**
   * @dev Returns the configs related to bridge voting slashing.
   *
   * @return _bridgeVotingThreshold The threshold to slash when a trusted organization does not vote for bridge
   * operators.
   * @return _bridgeVotingSlashAmount The amount of RON to slash bridge voting.
   *
   */
  function getBridgeVotingSlashingConfigs()
    external
    view
    returns (uint256 _bridgeVotingThreshold, uint256 _bridgeVotingSlashAmount);

  /**
   * @dev Sets the configs to slash bridge voting.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the event `BridgeVotingSlashingConfigsUpdated`.
   *
   * @param _threshold The threshold to slash when a trusted organization does not vote for bridge operators.
   * @param _slashAmount The amount of RON to slash bridge voting.
   *
   */
  function setBridgeVotingSlashingConfigs(uint256 _threshold, uint256 _slashAmount) external;
}
