// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./interfaces/IScheduledMaintenance.sol";
import "./interfaces/IRoninValidatorSet.sol";
import "./interfaces/IStaking.sol";
import "./extensions/HasValidatorContract.sol";

// TODO: add test for this contract
contract ScheduledMaintenance is IScheduledMaintenance, HasValidatorContract, Initializable {
  /// @dev Mapping from consensus address => maintenance schedule
  mapping(address => Schedule) internal _schedule;

  /// @dev The min block period to maintenance
  uint256 public minMaintenanceBlockPeriod;
  /// @dev The max block period to maintenance
  uint256 public maxMaintenanceBlockPeriod;
  /// @dev The min blocks from the current block to the start block
  uint256 public minOffset;
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
    uint256 _minMaintenanceBlockPeriod,
    uint256 _maxMaintenanceBlockPeriod,
    uint256 _minOffset,
    uint256 _maxSchedules
  ) external initializer {
    _setValidatorContract(__validatorContract);
    _setMaintenanceConfig(_minMaintenanceBlockPeriod, _maxMaintenanceBlockPeriod, _minOffset, _maxSchedules);
  }

  /**
   * @inheritdoc IScheduledMaintenance
   */
  function setMaintenanceConfig(
    uint256 _minMaintenanceBlockPeriod,
    uint256 _maxMaintenanceBlockPeriod,
    uint256 _minOffset,
    uint256 _maxSchedules
  ) external onlyAdmin {
    _setMaintenanceConfig(_minMaintenanceBlockPeriod, _maxMaintenanceBlockPeriod, _minOffset, _maxSchedules);
  }

  /**
   * @inheritdoc IScheduledMaintenance
   */
  function schedule(
    address _consensusAddr,
    uint256 _startedAtBlock,
    uint256 _endedAtBlock
  ) external override {
    IRoninValidatorSet _validator = _validatorContract;

    require(_validator.isValidator(_consensusAddr), "ScheduledMaintenance: consensus address must be a validator");
    require(
      _validator.isCandidateAdmin(_consensusAddr, msg.sender),
      "ScheduledMaintenance: method caller must be a candidate admin"
    );
    require(!scheduled(_consensusAddr), "ScheduledMaintenance: already scheduled");
    require(totalSchedules() < maxSchedules, "ScheduledMaintenance: exceeds total of schedules");
    require(block.number + minOffset <= _startedAtBlock, "ScheduledMaintenance: invalid offset size");
    require(_startedAtBlock < _endedAtBlock, "ScheduledMaintenance: start block must be less than end block");
    uint256 _blockPeriod = _endedAtBlock - _startedAtBlock;
    require(
      minMaintenanceBlockPeriod <= _blockPeriod && _blockPeriod <= maxMaintenanceBlockPeriod,
      "ScheduledMaintenance: invalid maintenance block period"
    );
    require(
      _validator.epochEndingAt(_startedAtBlock - 1),
      "ScheduledMaintenance: start block is not at the start of an epoch"
    );
    require(_validator.epochEndingAt(_endedAtBlock), "ScheduledMaintenance: end block is not at the end of an epoch");

    Schedule memory _s = Schedule(_startedAtBlock, _endedAtBlock);
    _schedule[_consensusAddr] = _s;
    emit MaintenanceScheduled(_consensusAddr, _s);
  }

  /**
   * @inheritdoc IScheduledMaintenance
   */
  function getSchedule(address _consensusAddr) external view returns (Schedule memory) {
    return _schedule[_consensusAddr];
  }

  /**
   * @inheritdoc IScheduledMaintenance
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
   * @inheritdoc IScheduledMaintenance
   */
  function totalSchedules() public view returns (uint256 _count) {
    address[] memory _validators = _validatorContract.getValidators();
    for (uint _i = 0; _i < _validators.length; _i++) {
      if (scheduled(_validators[_i])) {
        _count++;
      }
    }
  }

  /**
   * @inheritdoc IScheduledMaintenance
   */
  function maintaining(address _consensusAddr, uint256 _block) public view returns (bool) {
    Schedule memory _s = _schedule[_consensusAddr];
    return _s.startedAtBlock <= _block && _block <= _s.endedAtBlock;
  }

  /**
   * @inheritdoc IScheduledMaintenance
   */
  function scheduled(address _consensusAddr) public view override returns (bool) {
    return block.number <= _schedule[_consensusAddr].endedAtBlock;
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
    uint256 _minMaintenanceBlockPeriod,
    uint256 _maxMaintenanceBlockPeriod,
    uint256 _minOffset,
    uint256 _maxSchedules
  ) internal {
    require(_minMaintenanceBlockPeriod < _maxMaintenanceBlockPeriod, "ScheduledMaintenance: invalid block periods");
    minMaintenanceBlockPeriod = _minMaintenanceBlockPeriod;
    maxMaintenanceBlockPeriod = _maxMaintenanceBlockPeriod;
    minOffset = _minOffset;
    maxSchedules = _maxSchedules;
    emit MaintenanceConfigUpdated(_minMaintenanceBlockPeriod, _maxMaintenanceBlockPeriod, _minOffset, _maxSchedules);
  }
}
