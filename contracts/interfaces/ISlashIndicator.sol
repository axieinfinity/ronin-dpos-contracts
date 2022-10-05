// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ISlashIndicator {
  /// @dev Emitted when the validator is slashed for unavailability
  event UnavailabilitySlashed(address indexed validator, SlashType slashType, uint256 period);
  /// @dev Emitted when the thresholds updated
  event SlashThresholdsUpdated(uint256 felonyThreshold, uint256 misdemeanorThreshold);
  /// @dev Emitted when the amount of slashing felony updated
  event SlashFelonyAmountUpdated(uint256 slashFelonyAmount);
  /// @dev Emitted when the amount of slashing double sign updated
  event SlashDoubleSignAmountUpdated(uint256 slashDoubleSignAmount);
  /// @dev Emiited when the duration of jailing felony updated
  event FelonyJailDurationUpdated(uint256 felonyJailDuration);
  /// @dev Emiited when the constrain of ahead block in double signing updated
  event DoubleSigningConstrainBlocksUpdated(uint256 doubleSigningConstrainBlocks);
  /// @dev Emiited when the block number to jail the double signing validator to is updated
  event DoubleSigningJailUntilBlockUpdated(uint256 doubleSigningJailUntilBlock);

  enum SlashType {
    UNKNOWN,
    MISDEMEANOR,
    FELONY,
    DOUBLE_SIGNING
  }

  struct BlockHeader {
    /// @dev Keccak hash of the parent block
    bytes32 parentHash;
    /// @dev Keccak hash of the ommers block
    bytes32 ommersHash;
    /// @dev Beneficiary address, i.e. mining fee recipient
    address beneficiary;
    /// @dev Keccak hash of the root of the state trie post execution
    bytes32 stateRoot;
    /// @dev Keccak hash of the root of transaction trie
    bytes32 transactionsRoot;
    /// @dev Keccak hash of the root node of recipients in the transaction
    bytes32 receiptsRoot;
    /// @dev Bloom filter of two fields log address and log topic in the receipts
    bytes32[256] logsBloom;
    /// @dev Scalar value of the difficulty of the previous block
    uint256 difficulty;
    /// @dev Scalar value of the number of ancestor blocks, i.e. block height
    uint64 number;
    /// @dev Scalar value of the current limit of gas usage per block
    uint64 gasLimit;
    /// @dev Scalar value of the total gas spent of the transactions in this block
    uint64 gasUsed;
    /// @dev Scalar value of the output of Unix's time()
    uint64 timestamp;
    /// @dev The signature of the validators
    bytes32 extraData;
    /// @dev A 256-bit hash which, combined with the `nonce`, proves that a sufficient amount of computation has been carried out on this block
    bytes32 mixHash;
    /// @dev A 64-bit value which, combined with the `mixHash`, proves that a sufficient amount of computation has been carried out on this block
    uint8 nonce;
  }

  /**
   * @dev Slashes for unavailability by increasing the counter of validator with `_valAddr`.
   * If the counter passes the threshold, call the function from the validator contract.
   *
   * Requirements:
   * - Only coinbase can call this method
   *
   * Emits the event `UnavailabilitySlashed` when the threshold is reached.
   *
   */
  function slash(address _valAddr) external;

  /**
   * @dev Slashes for double signing
   *
   * Requirements:
   * - Only coinbase can call this method
   *
   * Emits the event `UnavailabilitySlashed` if the double signing evidence of the two headers valid
   */
  function slashDoubleSign(
    address _validatorAddr,
    BlockHeader calldata _header1,
    BlockHeader calldata _header2
  ) external;

  /**
   * @dev Sets the slash thresholds
   *
   * Requirements:
   * - Only admin can call this method
   *
   * Emits the event `SlashThresholdsUpdated`
   *
   */
  function setSlashThresholds(uint256 _felonyThreshold, uint256 _misdemeanorThreshold) external;

  /**
   * @dev Sets the slash felony amount
   *
   * Requirements:
   * - Only admin can call this method
   *
   * Emits the event `SlashFelonyAmountUpdated`
   *
   */
  function setSlashFelonyAmount(uint256 _slashFelonyAmount) external;

  /**
   * @dev Sets the slash double sign amount
   *
   * Requirements:
   * - Only admin can call this method
   *
   * Emits the event `SlashDoubleSignAmountUpdated`
   *
   */
  function setSlashDoubleSignAmount(uint256 _slashDoubleSignAmount) external;

  /**
   * @dev Sets the felony jail duration
   *
   * Requirements:
   * - Only admin can call this method
   *
   * Emits the event `FelonyJailDurationUpdated`
   *
   */
  function setFelonyJailDuration(uint256 _felonyJailDuration) external;

  /**
   * @dev Returns the current unavailability indicator of a validator.
   */
  function currentUnavailabilityIndicator(address _validator) external view returns (uint256);

  /**
   * @dev Returns the scaled thresholds based on the maintenance duration for unavailability slashing.
   */
  function unavailabilityThresholdsOf(address _addr, uint256 _block)
    external
    view
    returns (uint256 _misdemeanorThreshold, uint256 _felonyThreshold);

  /**
   * @dev Retursn the unavailability indicator in the period `_period` of a validator.
   */
  function getUnavailabilityIndicator(address _validator, uint256 _period) external view returns (uint256);

  /**
   * @dev Gets the unavailability thresholds.
   */
  function getUnavailabilityThresholds()
    external
    view
    returns (uint256 _misdemeanorThreshold, uint256 _felonyThreshold);

  /**
   * @dev Checks the slashed tier for unavailability of a validator.
   */
  function getUnavailabilitySlashType(address _validatorAddr, uint256 _period) external view returns (SlashType);
}
