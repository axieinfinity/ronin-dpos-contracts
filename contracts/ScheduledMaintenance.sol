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

  /// @dev The minimum block size to maintenance
  uint256 public minMaintenanceBlockSize;
  /// @dev The maximum block size to maintenance
  uint256 public maxMaintenanceBlockSize;
  /// @dev The minimum blocks from the current block to the start block
  uint256 public minOffset;
  /// @dev The maximum number of scheduled maintenances
  uint256 public maxSchedules;

  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(
    address __validatorContract,
    uint256 _minMaintenanceBlockSize,
    uint256 _maxMaintenanceBlockSize,
    uint256 _minOffset,
    uint256 _maxSchedules
  ) external initializer {
    _setValidatorContract(__validatorContract);
    // TODO: add setter
    assert(_minMaintenanceBlockSize < _maxMaintenanceBlockSize);
    minMaintenanceBlockSize = _minMaintenanceBlockSize;
    maxMaintenanceBlockSize = _maxMaintenanceBlockSize;
    minOffset = _minOffset;
    maxSchedules = _maxSchedules;
  }

  /**
   * @inheritdoc IScheduledMaintenance
   */
  function maintained(address _consensusAddr) public view override returns (bool) {
    Schedule memory _s = _schedule[_consensusAddr];
    return _s.startedAtBlock <= block.number && block.number <= _s.endedAtBlock;
  }

  /**
   * @inheritdoc IScheduledMaintenance
   */
  function scheduled(address _consensusAddr) public view override returns (bool) {
    return block.number <= _schedule[_consensusAddr].endedAtBlock;
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
  function schedule(
    address _consensusAddr,
    uint256 _startedAtBlock,
    uint256 _endedAtBlock
  ) external override {
    require(
      _validatorContract.isCandidateAdmin(_consensusAddr, msg.sender),
      "ScheduledMaintenance: method caller is not the candidate admin"
    );
    require(_validatorContract.isValidator(_consensusAddr), "ScheduledMaintenance: consensus address is not validator");
    require(!scheduled(_consensusAddr), "ScheduledMaintenance: already scheduled");
    require(totalSchedules() < maxSchedules, "ScheduledMaintenance: exceeds total of schedules");
    require(_startedAtBlock < _endedAtBlock, "ScheduledMaintenance: invalid request block");
    require(block.number + minOffset <= _startedAtBlock, "ScheduledMaintenance: invalid offset size");

    uint256 _blockSize = _endedAtBlock - _startedAtBlock;
    require(
      minMaintenanceBlockSize <= _blockSize && _blockSize <= maxMaintenanceBlockSize,
      "ScheduledMaintenance: invalid maintainance block size"
    );

    Schedule memory _s = Schedule(_startedAtBlock, _endedAtBlock);
    _schedule[_consensusAddr] = _s;
    emit MaintenanceScheduled(_consensusAddr, _s);
  }
}
