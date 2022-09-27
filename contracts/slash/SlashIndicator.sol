// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/ISlashIndicator.sol";
import "../extensions/HasValidatorContract.sol";
import "../extensions/HasMaintenanceContract.sol";
import "../libraries/Math.sol";

contract SlashIndicator is ISlashIndicator, HasValidatorContract, HasMaintenanceContract, Initializable {
  using Math for uint256;

  /// @dev Mapping from validator address => period index => unavailability indicator
  mapping(address => mapping(uint256 => uint256)) internal _unavailabilityIndicator;
  /// @dev Maping from validator address => period index => slash type
  mapping(address => mapping(uint256 => SlashType)) internal _unavailabilitySlashed;

  /// @dev The last block that a validator is slashed
  uint256 public lastSlashedBlock;

  /// @dev The number of blocks that the current block can be ahead of the double signed blocks
  uint256 public doubleSigningConstrainBlocks;

  /// @dev The threshold to slash when validator is unavailability reaches misdemeanor
  uint256 public misdemeanorThreshold;
  /// @dev The threshold to slash when validator is unavailability reaches felony
  uint256 public felonyThreshold;

  /// @dev The amount of RON to slash felony.
  uint256 public slashFelonyAmount;
  /// @dev The amount of RON to slash double sign.
  uint256 public slashDoubleSignAmount;
  /// @dev The block duration to jail a validator that reaches felony thresold.
  uint256 public felonyJailDuration;
  /// @dev The block duration to jail a validator that double signs block. This variable should be
  /// a constant of MAX_UINT since that validator is jailed forever.
  uint256 public doubleSigningJailDuration;

  modifier onlyCoinbase() {
    require(msg.sender == block.coinbase, "SlashIndicator: method caller must be coinbase");
    _;
  }

  modifier oncePerBlock() {
    require(
      block.number > lastSlashedBlock,
      "SlashIndicator: cannot slash a validator twice or slash more than one validator in one block"
    );
    _;
    lastSlashedBlock = block.number;
  }

  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(
    address __validatorContract,
    address __maintenanceContract,
    uint256 _misdemeanorThreshold,
    uint256 _felonyThreshold,
    uint256 _slashFelonyAmount,
    uint256 _slashDoubleSignAmount,
    uint256 _felonyJailBlocks,
    uint256 _doubleSigningConstrainBlocks
  ) external initializer {
    _setValidatorContract(__validatorContract);
    _setMaintenanceContract(__maintenanceContract);
    _setSlashThresholds(_felonyThreshold, _misdemeanorThreshold);
    _setSlashFelonyAmount(_slashFelonyAmount);
    _setSlashDoubleSignAmount(_slashDoubleSignAmount);
    _setFelonyJailDuration(_felonyJailBlocks);
    _setDoubleSigningConstrainBlocks(_doubleSigningConstrainBlocks);
    _setDoubleSigningJailDuration(type(uint256).max);
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                                SLASHING FUNCTIONS                                 //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc ISlashIndicator
   */
  function slash(address _validatorAddr) external override onlyCoinbase oncePerBlock {
    if (!_isSlashable(_validatorAddr)) {
      return;
    }

    uint256 _period = _validatorContract.periodOf(block.number);
    uint256 _count = ++_unavailabilityIndicator[_validatorAddr][_period];
    (uint256 _misdemeanorThreshold, uint256 _felonyThreshold) = unavailabilityThresholdsOf(
      _validatorAddr,
      block.number
    );

    SlashType _slashType = getUnavailabilitySlashType(_validatorAddr, _period);

    if (_count >= _felonyThreshold && _slashType < SlashType.FELONY) {
      _unavailabilitySlashed[_validatorAddr][_period] = SlashType.FELONY;
      emit UnavailabilitySlashed(_validatorAddr, SlashType.FELONY, _period);
      _validatorContract.slash(_validatorAddr, block.number + felonyJailDuration, slashFelonyAmount);
      return;
    }

    if (_count >= _misdemeanorThreshold && _slashType < SlashType.MISDEMEANOR) {
      _unavailabilitySlashed[_validatorAddr][_period] = SlashType.MISDEMEANOR;
      emit UnavailabilitySlashed(_validatorAddr, SlashType.MISDEMEANOR, _period);
      _validatorContract.slash(_validatorAddr, 0, 0);
      return;
    }
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function slashDoubleSign(
    address _validatorAddr,
    BlockHeader memory _header1,
    BlockHeader memory _header2
  ) external override onlyCoinbase oncePerBlock {
    if (!_isSlashable(_validatorAddr)) {
      return;
    }

    if (
      block.number > _header1.number + doubleSigningConstrainBlocks ||
      block.number > _header2.number + doubleSigningConstrainBlocks ||
      _header1.parentHash != _header2.parentHash
    ) {
      return;
    }

    bool _validEvidence = _validateEvidence(_header1, _header2);

    if (_validEvidence) {
      uint256 _period = _validatorContract.periodOf(block.number);
      _unavailabilitySlashed[_validatorAddr][_period] = SlashType.DOUBLE_SIGNING;
      emit UnavailabilitySlashed(_validatorAddr, SlashType.DOUBLE_SIGNING, _period);
      _validatorContract.slash(_validatorAddr, doubleSigningJailDuration, slashDoubleSignAmount);
    }
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                               GOVERNANCE FUNCTIONS                                //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc ISlashIndicator
   */
  function setSlashThresholds(uint256 _felonyThreshold, uint256 _misdemeanorThreshold) external override onlyAdmin {
    _setSlashThresholds(_felonyThreshold, _misdemeanorThreshold);
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function setSlashFelonyAmount(uint256 _slashFelonyAmount) external override onlyAdmin {
    _setSlashFelonyAmount(_slashFelonyAmount);
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function setSlashDoubleSignAmount(uint256 _slashDoubleSignAmount) external override onlyAdmin {
    _setSlashDoubleSignAmount(_slashDoubleSignAmount);
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function setFelonyJailDuration(uint256 _felonyJailDuration) external override onlyAdmin {
    _setFelonyJailDuration(_felonyJailDuration);
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                                  QUERY FUNCTIONS                                  //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc ISlashIndicator
   */
  function getUnavailabilitySlashType(address _validatorAddr, uint256 _period) public view returns (SlashType) {
    return _unavailabilitySlashed[_validatorAddr][_period];
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function unavailabilityThresholdsOf(address _addr, uint256 _block)
    public
    view
    returns (uint256 _misdemeanorThreshold, uint256 _felonyThreshold)
  {
    uint256 _blockLength = _validatorContract.numberOfBlocksInEpoch() * _validatorContract.numberOfEpochsInPeriod();
    uint256 _start = (_block / _blockLength) * _blockLength;
    uint256 _end = _start + _blockLength - 1;
    IMaintenance.Schedule memory _s = _maintenanceContract.getSchedule(_addr);

    bool _fromInRange = _s.from.inRange(_start, _end);
    bool _toInRange = _s.to.inRange(_start, _end);
    uint256 _availableDuration = _blockLength;
    if (_fromInRange && _toInRange) {
      _availableDuration -= _s.to - _s.from + 1;
    } else if (_fromInRange) {
      _availableDuration -= _end - _s.from + 1;
    } else if (_toInRange) {
      _availableDuration -= _s.to - _start + 1;
    }

    _misdemeanorThreshold = misdemeanorThreshold.scale(_availableDuration, _blockLength);
    _felonyThreshold = felonyThreshold.scale(_availableDuration, _blockLength);
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function currentUnavailabilityIndicator(address _validator) external view override returns (uint256) {
    return getUnavailabilityIndicator(_validator, _validatorContract.periodOf(block.number));
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function getUnavailabilityThresholds() external view override returns (uint256, uint256) {
    return (misdemeanorThreshold, felonyThreshold);
  }

  /**
   * @inheritdoc ISlashIndicator
   */
  function getUnavailabilityIndicator(address _validator, uint256 _period) public view override returns (uint256) {
    return _unavailabilityIndicator[_validator][_period];
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                                 HELPER FUNCTIONS                                  //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Sets the slash thresholds
   */
  function _setSlashThresholds(uint256 _felonyThreshold, uint256 _misdemeanorThreshold) internal {
    felonyThreshold = _felonyThreshold;
    misdemeanorThreshold = _misdemeanorThreshold;
    emit SlashThresholdsUpdated(_felonyThreshold, _misdemeanorThreshold);
  }

  /**
   * @dev Sets the slash felony amount
   */
  function _setSlashFelonyAmount(uint256 _slashFelonyAmount) internal {
    slashFelonyAmount = _slashFelonyAmount;
    emit SlashFelonyAmountUpdated(_slashFelonyAmount);
  }

  /**
   * @dev Sets the slash double sign amount
   */
  function _setSlashDoubleSignAmount(uint256 _slashDoubleSignAmount) internal {
    slashDoubleSignAmount = _slashDoubleSignAmount;
    emit SlashDoubleSignAmountUpdated(_slashDoubleSignAmount);
  }

  /**
   * @dev Sets the felony jail duration
   */
  function _setFelonyJailDuration(uint256 _felonyJailDuration) internal {
    felonyJailDuration = _felonyJailDuration;
    emit FelonyJailDurationUpdated(_felonyJailDuration);
  }

  /**
   * @dev Sets the double signing constrain blocks
   */
  function _setDoubleSigningConstrainBlocks(uint256 _doubleSigningConstrainBlocks) internal {
    doubleSigningConstrainBlocks = _doubleSigningConstrainBlocks;
    emit DoubleSigningConstrainBlocksUpdated(_doubleSigningConstrainBlocks);
  }

  /**
   * @dev Sets the double signing jail duration
   */
  function _setDoubleSigningJailDuration(uint256 _doubleSigningJailDuration) internal {
    doubleSigningJailDuration = _doubleSigningJailDuration;
    emit DoubleSigningJailDurationUpdated(_doubleSigningJailDuration);
  }

  function _isSlashable(address _addr) internal view returns (bool) {
    if (msg.sender == _addr) {
      return false;
    }

    if (!_validatorContract.isValidator(_addr)) {
      return false;
    }

    if (_maintenanceContract.maintaining(_addr, block.number)) {
      return false;
    }

    return true;
  }

  /**
   * @dev Validate the two submitted block header if they are produced by the same address
   *
   * Note: The recover process is done by pre-compiled contract. This function is marked as
   * virtual for implementing mocking contract for testing purpose.
   */
  function _validateEvidence(BlockHeader memory _header1, BlockHeader memory _header2)
    internal
    view
    virtual
    returns (bool _validEvidence)
  {
    /// FIXME: Choose either option 1 or option 2 belows.

    ///
    /// OPTION 1: Call by pre-compiled contract name
    ///

    // address _addr1 = headerRecover(_header1);
    // address _addr2 = headerRecover(_header2);
    // _validEvidence = (_addr1 == _addr2);

    ///
    /// OPTION 2: Call by pre-compiled contract address
    ///

    bytes memory _input = bytes.concat(_packBlockHeader(_header1), _packBlockHeader(_header2));
    uint _inputSize = _input.length;
    assembly {
      if iszero(staticcall(gas(), 0x20, _input, _inputSize, _validEvidence, 0x20)) {
        // FIXME:                 ^^^^
        //                        Replace by the actual pre-compiled contract address
        revert(0, 0)
      }

      _validEvidence := mload(_validEvidence)
    }
  }

  /**
   * @dev Packing the block header struct into a single bytes. Helper function for validating
   * evidence function.
   */
  function _packBlockHeader(BlockHeader memory _header) private pure returns (bytes memory) {
    return
      abi.encode(
        _header.parentHash,
        _header.ommersHash,
        _header.beneficiary,
        _header.stateRoot,
        _header.transactionsRoot,
        _header.receiptsRoot,
        _header.logsBloom,
        _header.difficulty,
        _header.number,
        _header.gasLimit,
        _header.gasUsed,
        _header.timestamp
      );
  }
}
