// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IBaseSlash.sol";

interface ISlashDoubleSign is IBaseSlash {
  /**
   * @dev Emitted when the configs to slash double sign is updated. See the method `getDoubleSignSlashingConfigs`
   * for param details.
   */
  event DoubleSignSlashingConfigsUpdated(uint256 slashDoubleSignAmount, uint256 doubleSigningJailUntilBlock);

  /**
   * @dev Slashes for double signing.
   *
   * Requirements:
   * - The method caller is coinbase.
   *
   * Emits the event `Slashed` if the double signing evidence of the two headers valid.
   */
  function slashDoubleSign(
    address _validatorAddr,
    bytes calldata _header1,
    bytes calldata _header2
  ) external;

  /**
   * @dev Returns the configs related to block producer slashing.
   *
   * @return _slashDoubleSignAmount The amount of RON to slash double sign.
   * @return _doubleSigningJailUntilBlock The block number that the punished validator will be jailed until, due to
   * double signing.
   *
   */
  function getDoubleSignSlashingConfigs()
    external
    view
    returns (uint256 _slashDoubleSignAmount, uint256 _doubleSigningJailUntilBlock);

  /**
   * @dev Sets the configs to slash block producers.
   *
   * Requirements:
   * - The method caller is admin.
   *
   * Emits the event `DoubleSignSlashingConfigsUpdated`.
   *
   * @param _slashAmount The amount of RON to slash double sign.
   * @param _jailUntilBlock The block number that the punished validator will be jailed until, due to double signing.
   *
   */
  function setDoubleSignSlashingConfigs(uint256 _slashAmount, uint256 _jailUntilBlock) external;
}
