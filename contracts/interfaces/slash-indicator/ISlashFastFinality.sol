// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IBaseSlash.sol";

interface ISlashFastFinality is IBaseSlash {
  /**
   * @dev Emitted when the configs to slash fast finality is updated. See the method `getFastFinalitySlashingConfigs`
   * for param details.
   */
  event FastFinalitySlashingConfigsUpdated(uint256 slashFastFinalityAmount, uint256 fastFinalityJailUntilBlock);

  /**
   * @dev Slashes for fast finality.
   *
   * Requirements:
   * - Only whitelisted addresses are allowed to call.
   *
   * Emits the event `Slashed` if the fast finality evidence of the two headers valid.
   */
  function slashFastFinality(
    address consensusAddr,
    bytes calldata voterPublicKey,
    uint256 targetBlockNumber,
    bytes32[2] calldata targetBlockHash,
    bytes[][2] calldata listOfPublicKey,
    bytes[2] calldata aggregatedSignature
  ) external;

  /**
   * @dev Returns the configs related to block producer slashing.
   *
   * @return slashFastFinalityAmount The amount of RON to slash fast finality.
   * @return fastFinalityJailUntilBlock The block number that the punished validator will be jailed until, due to
   * malicious fast finality.
   */
  function getFastFinalitySlashingConfigs()
    external
    view
    returns (uint256 slashFastFinalityAmount, uint256 fastFinalityJailUntilBlock);

  /**
   * @dev Sets the configs to slash block producers.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the event `FastFinalitySlashingConfigsUpdated`.
   *
   * @param slashAmount The amount of RON to slash fast finality.
   * @param jailUntilBlock The block number that the punished validator will be jailed until, due to fast finality.
   *
   */
  function setFastFinalitySlashingConfigs(uint256 slashAmount, uint256 jailUntilBlock) external;
}
