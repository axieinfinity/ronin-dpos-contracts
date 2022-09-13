// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IStakingVesting {
  /// @dev Emitted when the block bonus is transferred.
  event BlockBonusTransferred(uint256 indexed blockNumber, address indexed recipient, uint256 amount);
  /// @dev Emitted when the block bonus is updated
  event BonusPerBlockUpdated(uint256);
  /// @dev Emitted when the address of validator contract is updated.
  event ValidatorContractUpdated(address);

  /**
   * @dev Returns the bonus amount for the block `_block`.
   */
  function blockBonus(uint256 _block) external view returns (uint256);

  /**
   * @dev Receives RON from any address.
   */
  function receiveRON() external payable;

  /**
   * @dev Returns the last block number that the bonus reward is sent.
   */
  function lastBonusSentBlock() external view returns (uint256);

  /**
   * @dev Transfers the bonus reward whenever a new block is mined.
   * Returns the amount of RON sent to validator contract.
   *
   * Requirements:
   * - The method caller is validator contract.
   * - The method must be called only once per block.
   *
   * Emits the event `BlockBonusTransferred`.
   *
   */
  function requestBlockBonus() external returns (uint256);
}
