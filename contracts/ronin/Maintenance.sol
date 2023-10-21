// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/IMaintenance.sol";
import "../interfaces/validator/IRoninValidatorSet.sol";
import "../extensions/collections/HasContracts.sol";
import "../libraries/Math.sol";
import { HasValidatorDeprecated } from "../utils/DeprecatedSlots.sol";
import { ErrUnauthorized, RoleAccess } from "../utils/CommonErrors.sol";

contract Maintenance is IMaintenance, HasContracts, HasValidatorDeprecated, Initializable {
  using Math for uint256;

  /// @dev Mapping from consensus address => maintenance schedule.
  mapping(address => Schedule) internal _schedule;

  /// @dev The min duration to maintenance in blocks.
  uint256 public minMaintenanceDurationInBlock;
  /// @dev The max duration to maintenance in blocks.
  uint256 public maxMaintenanceDurationInBlock;
  /// @dev The offset to the min block number that the schedule can start.
  uint256 public minOffsetToStartSchedule;
  /// @dev The offset to the max block number that the schedule can start.
  uint256 public maxOffsetToStartSchedule;
  /// @dev The max number of scheduled maintenances.
  uint256 public maxSchedule;
  /// @dev The cooldown time to request new schedule.
  uint256 public cooldownSecsToMaintain;

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
    uint256 _maxSchedules,
    uint256 _cooldownSecsToMaintain
  ) external initializer {
    _setContract(ContractType.VALIDATOR, __validatorContract);
    _setMaintenanceConfig(
      _minMaintenanceDurationInBlock,
      _maxMaintenanceDurationInBlock,
      _minOffsetToStartSchedule,
      _maxOffsetToStartSchedule,
      _maxSchedules,
      _cooldownSecsToMaintain
    );
  }

  function initializeV2() external reinitializer(2) {
    _setContract(ContractType.VALIDATOR, ______deprecatedValidator);
    delete ______deprecatedValidator;
  }

  /**
   * @inheritdoc IMaintenance
   */
  function setMaintenanceConfig(
    uint256 _minMaintenanceDurationInBlock,
    uint256 _maxMaintenanceDurationInBlock,
    uint256 _minOffsetToStartSchedule,
    uint256 _maxOffsetToStartSchedule,
    uint256 _maxSchedules,
    uint256 _cooldownSecsToMaintain
  ) external onlyAdmin {
    _setMaintenanceConfig(
      _minMaintenanceDurationInBlock,
      _maxMaintenanceDurationInBlock,
      _minOffsetToStartSchedule,
      _maxOffsetToStartSchedule,
      _maxSchedules,
      _cooldownSecsToMaintain
    );
  }

  /**
   * @inheritdoc IMaintenance
   */
  function schedule(address _consensusAddr, uint256 _startedAtBlock, uint256 _endedAtBlock) external override {
    IRoninValidatorSet _validator = IRoninValidatorSet(getContract(ContractType.VALIDATOR));

    if (!_validator.isBlockProducer(_consensusAddr)) revert ErrUnauthorized(msg.sig, RoleAccess.BLOCK_PRODUCER);
    if (!_validator.isCandidateAdmin(_consensusAddr, msg.sender))
      revert ErrUnauthorized(msg.sig, RoleAccess.CANDIDATE_ADMIN);
    if (checkScheduled(_consensusAddr)) revert ErrAlreadyScheduled();
    if (!checkCooldownEnded(_consensusAddr)) revert ErrCooldownTimeNotYetEnded();
    if (totalSchedule() >= maxSchedule) revert ErrTotalOfSchedulesExceeded();
    if (!_startedAtBlock.inRange(block.number + minOffsetToStartSchedule, block.number + maxOffsetToStartSchedule)) {
      revert ErrStartBlockOutOfRange();
    }
    if (_startedAtBlock >= _endedAtBlock) revert ErrStartBlockOutOfRange();

    uint256 _maintenanceElapsed = _endedAtBlock - _startedAtBlock + 1;

    if (!_maintenanceElapsed.inRange(minMaintenanceDurationInBlock, maxMaintenanceDurationInBlock)) {
      revert ErrInvalidMaintenanceDuration();
    }
    if (!_validator.epochEndingAt(_startedAtBlock - 1)) revert ErrStartBlockOutOfRange();
    if (!_validator.epochEndingAt(_endedAtBlock)) revert ErrEndBlockOutOfRange();

    Schedule storage _sSchedule = _schedule[_consensusAddr];
    _sSchedule.from = _startedAtBlock;
    _sSchedule.to = _endedAtBlock;
    _sSchedule.lastUpdatedBlock = block.number;
    _sSchedule.requestTimestamp = block.timestamp;
    emit MaintenanceScheduled(_consensusAddr, _sSchedule);
  }

  /**
   * @inheritdoc IMaintenance
   */
  function cancelSchedule(address _consensusAddr) external override {
    if (!IRoninValidatorSet(getContract(ContractType.VALIDATOR)).isCandidateAdmin(_consensusAddr, msg.sender)) {
      revert ErrUnauthorized(msg.sig, RoleAccess.CANDIDATE_ADMIN);
    }
    if (!checkScheduled(_consensusAddr)) revert ErrUnexistedSchedule();
    if (checkMaintained(_consensusAddr, block.number)) revert ErrAlreadyOnMaintenance();

    Schedule storage _sSchedule = _schedule[_consensusAddr];
    delete _sSchedule.from;
    delete _sSchedule.to;
    _sSchedule.lastUpdatedBlock = block.number;
    emit MaintenanceScheduleCancelled(_consensusAddr);
  }

  /**
   * @inheritdoc IMaintenance
   */
  function getSchedule(address _consensusAddr) external view override returns (Schedule memory) {
    return _schedule[_consensusAddr];
  }

  /**
   * @inheritdoc IMaintenance
   */
  function checkManyMaintained(
    address[] calldata _addrList,
    uint256 _block
  ) external view override returns (bool[] memory _resList) {
    _resList = new bool[](_addrList.length);
    for (uint _i = 0; _i < _addrList.length; ) {
      _resList[_i] = checkMaintained(_addrList[_i], _block);

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @inheritdoc IMaintenance
   */
  function checkManyMaintainedInBlockRange(
    address[] calldata _addrList,
    uint256 _fromBlock,
    uint256 _toBlock
  ) external view override returns (bool[] memory _resList) {
    _resList = new bool[](_addrList.length);
    for (uint _i = 0; _i < _addrList.length; ) {
      _resList[_i] = _maintainingInBlockRange(_addrList[_i], _fromBlock, _toBlock);

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @inheritdoc IMaintenance
   */
  function totalSchedule() public view override returns (uint256 _count) {
    address[] memory _validators = IRoninValidatorSet(getContract(ContractType.VALIDATOR)).getValidators();
    unchecked {
      for (uint _i = 0; _i < _validators.length; _i++) {
        if (checkScheduled(_validators[_i])) {
          _count++;
        }
      }
    }
  }

  /**
   * @inheritdoc IMaintenance
   */
  function checkMaintained(address _consensusAddr, uint256 _block) public view override returns (bool) {
    Schedule storage _s = _schedule[_consensusAddr];
    return _s.from <= _block && _block <= _s.to;
  }

  /**
   * @inheritdoc IMaintenance
   */
  function checkMaintainedInBlockRange(
    address _consensusAddr,
    uint256 _fromBlock,
    uint256 _toBlock
  ) public view override returns (bool) {
    return _maintainingInBlockRange(_consensusAddr, _fromBlock, _toBlock);
  }

  /**
   * @inheritdoc IMaintenance
   */
  function checkScheduled(address _consensusAddr) public view override returns (bool) {
    return block.number <= _schedule[_consensusAddr].to;
  }

  /**
   * @inheritdoc IMaintenance
   */
  function checkCooldownEnded(address _consensusAddr) public view override returns (bool) {
    return block.timestamp > _schedule[_consensusAddr].requestTimestamp + cooldownSecsToMaintain;
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
    uint256 _maxSchedule,
    uint256 _cooldownSecsToMaintain
  ) internal {
    if (_minMaintenanceDurationInBlock >= _maxMaintenanceDurationInBlock) revert ErrInvalidMaintenanceDurationConfig();
    if (_minOffsetToStartSchedule >= _maxOffsetToStartSchedule) revert ErrInvalidOffsetToStartScheduleConfigs();

    minMaintenanceDurationInBlock = _minMaintenanceDurationInBlock;
    maxMaintenanceDurationInBlock = _maxMaintenanceDurationInBlock;
    minOffsetToStartSchedule = _minOffsetToStartSchedule;
    maxOffsetToStartSchedule = _maxOffsetToStartSchedule;
    maxSchedule = _maxSchedule;
    cooldownSecsToMaintain = _cooldownSecsToMaintain;
    emit MaintenanceConfigUpdated(
      _minMaintenanceDurationInBlock,
      _maxMaintenanceDurationInBlock,
      _minOffsetToStartSchedule,
      _maxOffsetToStartSchedule,
      _maxSchedule,
      _cooldownSecsToMaintain
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
