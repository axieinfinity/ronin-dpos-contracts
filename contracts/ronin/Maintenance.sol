// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/IMaintenance.sol";
import "../interfaces/IRoninValidatorSet.sol";
import "../extensions/collections/HasValidatorContract.sol";
import "../libraries/Math.sol";

contract Maintenance is IMaintenance, HasValidatorContract, Initializable {
  using Math for uint256;

  /// @dev Mapping from consensus address => maintenance schedule
  mapping(address => Schedule) internal _schedule;

  /// @dev The min block period to maintenance
  uint256 public minMaintenanceDurationInBlock;
  /// @dev The max block period to maintenance
  uint256 public maxMaintenanceDurationInBlock;
  /// @dev The offset to the min block number that the schedule can start
  uint256 public minOffsetToStartSchedule;
  /// @dev The offset to the max block number that the schedule can start
  uint256 public maxOffsetToStartSchedule;
  /// @dev The max number of scheduled maintenances
  uint256 public maxSchedules;

  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(
    address __validatorContract,
    uint256 _minMaintenanceDurationInBlock,
    uint256 _maxMaintenanceDurationInBlock,
    uint256 _minOffsetToStartSchedule,
    uint256 _maxOffsetToStartSchedule,
    uint256 _maxSchedules
  ) external initializer {
    _setValidatorContract(__validatorContract);
    _setMaintenanceConfig(
      _minMaintenanceDurationInBlock,
      _maxMaintenanceDurationInBlock,
      _minOffsetToStartSchedule,
      _maxOffsetToStartSchedule,
      _maxSchedules
    );
  }

  /**
   * @inheritdoc IMaintenance
   */
  function setMaintenanceConfig(
    uint256 _minMaintenanceDurationInBlock,
    uint256 _maxMaintenanceDurationInBlock,
    uint256 _minOffsetToStartSchedule,
    uint256 _maxOffsetToStartSchedule,
    uint256 _maxSchedules
  ) external onlyAdmin {
    _setMaintenanceConfig(
      _minMaintenanceDurationInBlock,
      _maxMaintenanceDurationInBlock,
      _minOffsetToStartSchedule,
      _maxOffsetToStartSchedule,
      _maxSchedules
    );
  }

  /**
   * @inheritdoc IMaintenance
   */
  function schedule(
    address _consensusAddr,
    uint256 _startedAtBlock,
    uint256 _endedAtBlock
  ) external override {
    IRoninValidatorSet _validator = _validatorContract;

    require(_validator.isBlockProducer(_consensusAddr), "Maintenance: consensus address must be a block producer");
    require(
      _validator.isCandidateAdmin(_consensusAddr, msg.sender),
      "Maintenance: method caller must be a candidate admin"
    );
    require(!scheduled(_consensusAddr), "Maintenance: already scheduled");
    require(totalSchedules() < maxSchedules, "Maintenance: exceeds total of schedules");
    require(
      _startedAtBlock.inRange(block.number + minOffsetToStartSchedule, block.number + maxOffsetToStartSchedule),
      "Maintenance: start block is out of offset"
    );
    require(_startedAtBlock < _endedAtBlock, "Maintenance: start block must be less than end block");
    uint256 _blockPeriod = _endedAtBlock - _startedAtBlock;
    require(
      _blockPeriod.inRange(minMaintenanceDurationInBlock, maxMaintenanceDurationInBlock),
      "Maintenance: invalid maintenance duration"
    );
    require(_validator.epochEndingAt(_startedAtBlock - 1), "Maintenance: start block is not at the start of an epoch");
    require(_validator.epochEndingAt(_endedAtBlock), "Maintenance: end block is not at the end of an epoch");

    Schedule storage _sSchedule = _schedule[_consensusAddr];
    _sSchedule.from = _startedAtBlock;
    _sSchedule.to = _endedAtBlock;
    _sSchedule.lastUpdatedBlock = block.number;
    emit MaintenanceScheduled(_consensusAddr, _sSchedule);
  }

  /**
   * @inheritdoc IMaintenance
   */
  function getSchedule(address _consensusAddr) external view returns (Schedule memory) {
    return _schedule[_consensusAddr];
  }

  /**
   * @inheritdoc IMaintenance
   */
  function bulkMaintaining(address[] calldata _addrList, uint256 _block)
    external
    view
    override
    returns (bool[] memory _resList)
  {
    _resList = new bool[](_addrList.length);
    for (uint _i = 0; _i < _addrList.length; _i++) {
      _resList[_i] = maintaining(_addrList[_i], _block);
    }
  }

  /**
   * @inheritdoc IMaintenance
   */
  function bulkMaintainingInBlockRange(
    address[] calldata _addrList,
    uint256 _fromBlock,
    uint256 _toBlock
  ) external view override returns (bool[] memory _resList) {
    _resList = new bool[](_addrList.length);
    for (uint _i = 0; _i < _addrList.length; _i++) {
      _resList[_i] = _maintainingInBlockRange(_addrList[_i], _fromBlock, _toBlock);
    }
  }

  /**
   * @inheritdoc IMaintenance
   */
  function totalSchedules() public view override returns (uint256 _count) {
    address[] memory _validators = _validatorContract.getValidators();
    for (uint _i = 0; _i < _validators.length; _i++) {
      if (scheduled(_validators[_i])) {
        _count++;
      }
    }
  }

  /**
   * @inheritdoc IMaintenance
   */
  function maintaining(address _consensusAddr, uint256 _block) public view returns (bool) {
    Schedule storage _s = _schedule[_consensusAddr];
    return _s.from <= _block && _block <= _s.to;
  }

  /**
   * @inheritdoc IMaintenance
   */
  function maintainingInBlockRange(
    address _consensusAddr,
    uint256 _fromBlock,
    uint256 _toBlock
  ) public view override returns (bool) {
    return _maintainingInBlockRange(_consensusAddr, _fromBlock, _toBlock);
  }

  /**
   * @inheritdoc IMaintenance
   */
  function scheduled(address _consensusAddr) public view override returns (bool) {
    return block.number <= _schedule[_consensusAddr].to;
  }

  /**
   * @dev Sets the min block period and max block period to maintenance.
   *
   * Requirements:
   * - The max period is larger than the min period.
   *
   * Emits the event `MaintenanceConfigUpdated`.
   *
   */
  function _setMaintenanceConfig(
    uint256 _minMaintenanceDurationInBlock,
    uint256 _maxMaintenanceDurationInBlock,
    uint256 _minOffsetToStartSchedule,
    uint256 _maxOffsetToStartSchedule,
    uint256 _maxSchedules
  ) internal {
    require(
      _minMaintenanceDurationInBlock < _maxMaintenanceDurationInBlock,
      "Maintenance: invalid maintenance duration configs"
    );
    minMaintenanceDurationInBlock = _minMaintenanceDurationInBlock;
    maxMaintenanceDurationInBlock = _maxMaintenanceDurationInBlock;
    minOffsetToStartSchedule = _minOffsetToStartSchedule;
    maxOffsetToStartSchedule = _maxOffsetToStartSchedule;
    maxSchedules = _maxSchedules;
    emit MaintenanceConfigUpdated(
      _minMaintenanceDurationInBlock,
      _maxMaintenanceDurationInBlock,
      _minOffsetToStartSchedule,
      _maxOffsetToStartSchedule,
      _maxSchedules
    );
  }

  /**
   * @dev Check if the validator was maintaining in the current period.
   *
   * Note: This method should be called at the end of the period.
   */
  function _maintainingInBlockRange(
    address _consensusAddr,
    uint256 _fromBlock,
    uint256 _toBlock
  ) private view returns (bool) {
    Schedule storage _s = _schedule[_consensusAddr];
    return Math.twoRangeOverlap(_fromBlock, _toBlock, _s.from, _s.to);
  }
}
