// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IStakingVesting {
  /// @dev Emitted when the block bonus for validator is transferred.
  event ValidatorBonusTransferred(uint256 indexed blockNumber, address indexed recipient, uint256 amount);
  /// @dev Emitted when the block bonus for bridge operator is transferred.
  event BridgeOperatorBonusTransferred(uint256 indexed blockNumber, address indexed recipient, uint256 amount);
  /// @dev Emitted when the block bonus for validator is updated
  event ValidatorBonusPerBlockUpdated(uint256);
  /// @dev Emitted when the block bonus for bridge operator is updated
  event BridgeOperatorBonusPerBlockUpdated(uint256);

  /**
   * @dev Returns the bonus amount for the validator at `_block`.
   */
  function validatorBlockBonus(uint256 _block) external view returns (uint256);

  /**
   * @dev Returns the bonus amount for the bridge validator at `_block`.
   */
  function bridgeOperatorBlockBonus(uint256 _block) external view returns (uint256);

  /**
   * @dev Receives RON from any address.
   */
  function receiveRON() external payable;

  /**
   * @dev Returns the last block number that the staking vesting is sent for the validator.
   */
  function lastBlockSendingValidatorBonus() external view returns (uint256);

  /**
   * @dev Returns the last block number that the staking vesting is sent for the bridge operator.
   */
  function lastBlockSendingBridgeOperatorBonus() external view returns (uint256);

  /**
   * @dev Does two actions as in `requestValidatorBonus` and `requestBridgeOperatorBonus`. Returns
   * two amounts of bonus correspondingly.
   *
   * Requirements:
   * - The method caller is validator contract.
   * - The method must be called only once per block.
   *
   * Emits the event `ValidatorBonusTransferred` and/or `BridgeOperatorBonusTransferred`
   *
   */
  function requestBonus() external returns (uint256 _validatorBonus, uint256 _bridgeOperatorBonus);

  /**
   * @dev Transfers the staking vesting for the validator whenever a new block is mined.
   * Returns the amount of RON sent to validator contract.
   *
   * Requirements:
   * - The method caller is validator contract.
   * - The method must be called only once per block.
   *
   * Emits the event `ValidatorBonusTransferred`.
   *
   */
  function requestValidatorBonus() external returns (uint256);

  /**
   * @dev Transfers the staking vesting for the bridge operator whenever a new block is mined.
   * Returns the amount of RON sent to validator contract.
   *
   * Requirements:
   * - The method caller is validator contract.
   * - The method must be called only once per block.
   *
   * Emits the event `BridgeOperatorBonusTransferred`.
   *
   */
  function requestBridgeOperatorBonus() external returns (uint256);
}
