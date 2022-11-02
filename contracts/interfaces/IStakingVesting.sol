// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IStakingVesting {
  /// @dev Emitted when the block bonus for block producer is transferred.
  event BonusTransferred(
    uint256 indexed blockNumber,
    address indexed recipient,
    uint256 blockProducerAmount,
    uint256 bridgeOperatorAmount
  );
  /// @dev Emitted when the transfer of block bonus for block producer is failed.
  event BonusTransferFailed(
    uint256 indexed blockNumber,
    address indexed recipient,
    uint256 blockProducerAmount,
    uint256 bridgeOperatorAmount
  );
  /// @dev Emitted when the block bonus for block producer is updated
  event BlockProducerBonusPerBlockUpdated(uint256);
  /// @dev Emitted when the block bonus for bridge operator is updated
  event BridgeOperatorBonusPerBlockUpdated(uint256);

  /**
   * @dev Returns the bonus amount for the block producer at `_block`.
   */
  function blockProducerBlockBonus(uint256 _block) external view returns (uint256);

  /**
   * @dev Returns the bonus amount for the bridge validator at `_block`.
   */
  function bridgeOperatorBlockBonus(uint256 _block) external view returns (uint256);

  /**
   * @dev Receives RON from any address.
   */
  function receiveRON() external payable;

  /**
   * @dev Returns the last block number that the staking vesting is sent.
   */
  function lastBlockSendingBonus() external view returns (uint256);

  /**
   * @dev Transfers the staking vesting for the block producer and the bridge operator whenever a new block is mined.
   *
   * Requirements:
   * - The method caller must be validator contract.
   * - The method must be called only once per block.
   *
   * Emits the event `BonusTransferred` or `BonusTransferFailed`.
   *
   * Notes:
   * - The method does not revert when the contract balance is insufficient to send bonus. This assure the submit reward method
   * will not be reverted, and the underlying nodes does not hang.
   *
   * @return _success Whether the transfer is successfully. This returns false mostly because this contract is out of balance.
   * @return _blockProducerBonus The amount of bonus actually sent for the block producer, returns 0 when the transfer is failed.
   * @return _bridgeOperatorBonus The amount of bonus actually sent for the bridge operator, returns 0 when the transfer is failed.
   *
   */
  function requestBonus()
    external
    returns (
      bool _success,
      uint256 _blockProducerBonus,
      uint256 _bridgeOperatorBonus
    );
}
