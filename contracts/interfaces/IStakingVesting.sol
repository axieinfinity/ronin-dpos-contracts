// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IStakingVesting {
  /**
   * @dev Error thrown when attempting to send a bonus that has already been sent.
   */
  error ErrBonusAlreadySent();

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
    uint256 bridgeOperatorAmount,
    uint256 contractBalance
  );
  /// @dev Emitted when the block bonus for block producer is updated
  event BlockProducerBonusPerBlockUpdated(uint256);
  /// @dev Emitted when the block bonus for bridge operator is updated
  event BridgeOperatorBonusPerBlockUpdated(uint256);
  /// @dev Emitted when the percent of fast finality reward is updated
  event FastFinalityRewardPercentageUpdated(uint256);

  /**
   * @dev Returns the bonus amount for the block producer at `_block`.
   */
  function blockProducerBlockBonus(uint256 _block) external view returns (uint256);

  /**
   * @dev Returns the bonus amount for the bridge validator at `_block`.
   */
  function bridgeOperatorBlockBonus(uint256 _block) external view returns (uint256);

  /**
   * @dev Returns the percentage of fast finality reward.
   */
  function fastFinalityRewardPercentage() external view returns (uint256);

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
   * @param forBlockProducer Indicates whether requesting the bonus for the block procucer, in case of being in jail or relevance.
   * @param forBridgeOperator Indicates whether requesting the bonus for the bridge operator.
   *
   * @return success Whether the transfer is successfully. This returns false mostly because this contract is out of balance.
   * @return blockProducerBonus The amount of bonus actually sent for the block producer, returns 0 when the transfer is failed.
   * @return bridgeOperatorBonus The amount of bonus actually sent for the bridge operator, returns 0 when the transfer is failed.
   * @return fastFinalityRewardPercentage The percent of fast finality reward, returns 0 when the transfer is failed.
   *
   */
  function requestBonus(
    bool forBlockProducer,
    bool forBridgeOperator
  )
    external
    returns (
      bool success,
      uint256 blockProducerBonus,
      uint256 bridgeOperatorBonus,
      uint256 fastFinalityRewardPercentage
    );

  /**
   * @dev Sets the bonus amount per block for block producer.
   *
   * Emits the event `BlockProducerBonusPerBlockUpdated`.
   *
   * Requirements:
   * - The method caller is admin.
   *
   */
  function setBlockProducerBonusPerBlock(uint256 _amount) external;

  /**
   * @dev Sets the bonus amount per block for bridge operator.
   *
   * Emits the event `BridgeOperatorBonusPerBlockUpdated`.
   *
   * Requirements:
   * - The method caller is admin.
   *
   */
  function setBridgeOperatorBonusPerBlock(uint256 _amount) external;

  /**
   * @dev Sets the percent of fast finality reward.
   *
   * Emits the event `FastFinalityRewardPercentageUpdated`.
   *
   * Requirements:
   * - The method caller is admin.
   *
   */
  function setFastFinalityRewardPercentage(uint256 _percent) external;
}
