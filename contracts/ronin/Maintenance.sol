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
  uint256 public _minMaintenanceDurationInBlock;
  /// @dev The max duration to maintenance in blocks.
  uint256 public _maxMaintenanceDurationInBlock;
  /// @dev The offset to the min block number that the schedule can start.
  uint256 public _minOffsetToStartSchedule;
  /// @dev The offset to the max block number that the schedule can start.
  uint256 public _maxOffsetToStartSchedule;
  /// @dev The max number of scheduled maintenances.
  uint256 public _maxSchedules;
  /// @dev The cooldown time to request new schedule.
  uint256 public _cooldownSecsToMaintain;

  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(
    address validatorContract,
    uint256 minMaintenanceDurationInBlock_,
    uint256 maxMaintenanceDurationInBlock_,
    uint256 minOffsetToStartSchedule_,
    uint256 maxOffsetToStartSchedule_,
    uint256 maxSchedules_,
    uint256 cooldownSecsToMaintain_
  ) external initializer {
    _setContract(ContractType.VALIDATOR, validatorContract);
    _setMaintenanceConfig(
      minMaintenanceDurationInBlock_,
      maxMaintenanceDurationInBlock_,
      minOffsetToStartSchedule_,
      maxOffsetToStartSchedule_,
      maxSchedules_,
      cooldownSecsToMaintain_
    );
  }

  function initializeV2() external reinitializer(2) {
    _setContract(ContractType.VALIDATOR, ______deprecatedValidator);
    delete ______deprecatedValidator;
  }

  /**
   * @inheritdoc IMaintenance
   */
  function minMaintenanceDurationInBlock() external view returns (uint256) {
    return _minMaintenanceDurationInBlock;
  }

  /**
   * @inheritdoc IMaintenance
   */
  function maxMaintenanceDurationInBlock() external view returns (uint256) {
    return _maxMaintenanceDurationInBlock;
  }

  /**
   * @inheritdoc IMaintenance
   */
  function minOffsetToStartSchedule() external view returns (uint256) {
    return _minOffsetToStartSchedule;
  }

  /**
   * @inheritdoc IMaintenance
   */
  function maxOffsetToStartSchedule() external view returns (uint256) {
    return _maxOffsetToStartSchedule;
  }

  /**
   * @inheritdoc IMaintenance
   */
  function maxSchedules() external view returns (uint256) {
    return _maxSchedules;
  }

  /**
   * @inheritdoc IMaintenance
   */
  function cooldownSecsToMaintain() external view returns (uint256) {
    return _cooldownSecsToMaintain;
  }

  /**
   * @inheritdoc IMaintenance
   */
  function setMaintenanceConfig(
    uint256 minMaintenanceDurationInBlock_,
    uint256 maxMaintenanceDurationInBlock_,
    uint256 minOffsetToStartSchedule_,
    uint256 maxOffsetToStartSchedule_,
    uint256 maxSchedules_,
    uint256 cooldownSecsToMaintain_
  ) external onlyAdmin {
    _setMaintenanceConfig(
      minMaintenanceDurationInBlock_,
      maxMaintenanceDurationInBlock_,
      minOffsetToStartSchedule_,
      maxOffsetToStartSchedule_,
      maxSchedules_,
      cooldownSecsToMaintain_
    );
  }

  /**
   * @inheritdoc IMaintenance
   */
  function schedule(address consensusAddr, uint256 startedAtBlock, uint256 endedAtBlock) external override {
    IRoninValidatorSet validator = IRoninValidatorSet(getContract(ContractType.VALIDATOR));

    if (!validator.isBlockProducer(consensusAddr)) revert ErrUnauthorized(msg.sig, RoleAccess.BLOCK_PRODUCER);
    if (!validator.isCandidateAdmin(consensusAddr, msg.sender))
      revert ErrUnauthorized(msg.sig, RoleAccess.CANDIDATE_ADMIN);
    if (checkScheduled(consensusAddr)) revert ErrAlreadyScheduled();
    if (!checkCooldownEnds(consensusAddr)) revert ErrCooldownTimeNotYetEnded();
    if (totalSchedules() >= _maxSchedules) revert ErrTotalOfSchedulesExceeded();
    if (!startedAtBlock.inRange(block.number + _minOffsetToStartSchedule, block.number + _maxOffsetToStartSchedule)) {
      revert ErrStartBlockOutOfRange();
    }
    if (startedAtBlock >= endedAtBlock) revert ErrStartBlockOutOfRange();

    uint256 maintenanceElapsed = endedAtBlock - startedAtBlock + 1;

    if (!maintenanceElapsed.inRange(_minMaintenanceDurationInBlock, _maxMaintenanceDurationInBlock)) {
      revert ErrInvalidMaintenanceDuration();
    }
    if (!validator.epochEndingAt(startedAtBlock - 1)) revert ErrStartBlockOutOfRange();
    if (!validator.epochEndingAt(endedAtBlock)) revert ErrEndBlockOutOfRange();

    Schedule storage _sSchedule = _schedule[consensusAddr];
    _sSchedule.from = startedAtBlock;
    _sSchedule.to = endedAtBlock;
    _sSchedule.lastUpdatedBlock = block.number;
    _sSchedule.requestTimestamp = block.timestamp;
    emit MaintenanceScheduled(consensusAddr, _sSchedule);
  }

  /**
   * @inheritdoc IMaintenance
   */
  function cancelSchedule(address consensusAddr) external override {
    if (!IRoninValidatorSet(getContract(ContractType.VALIDATOR)).isCandidateAdmin(consensusAddr, msg.sender)) {
      revert ErrUnauthorized(msg.sig, RoleAccess.CANDIDATE_ADMIN);
    }
    if (!checkScheduled(consensusAddr)) revert ErrUnexistedSchedule();
    if (checkMaintained(consensusAddr, block.number)) revert ErrAlreadyOnMaintenance();

    Schedule storage _sSchedule = _schedule[consensusAddr];
    delete _sSchedule.from;
    delete _sSchedule.to;
    _sSchedule.lastUpdatedBlock = block.number;
    emit MaintenanceScheduleCancelled(consensusAddr);
  }

  /**
   * @inheritdoc IMaintenance
   */
  function getSchedule(address consensusAddr) external view override returns (Schedule memory) {
    return _schedule[consensusAddr];
  }

  /**
   * @inheritdoc IMaintenance
   */
  function checkManyMaintained(
    address[] calldata addrList,
    uint256 atBlock
  ) external view override returns (bool[] memory resList) {
    resList = new bool[](addrList.length);
    for (uint i = 0; i < addrList.length; ) {
      resList[i] = checkMaintained(addrList[i], atBlock);

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @inheritdoc IMaintenance
   */
  function checkManyMaintainedInBlockRange(
    address[] calldata addrList,
    uint256 fromBlock,
    uint256 toBlock
  ) external view override returns (bool[] memory resList) {
    resList = new bool[](addrList.length);
    for (uint i = 0; i < addrList.length; ) {
      resList[i] = _maintainingInBlockRange(addrList[i], fromBlock, toBlock);

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @inheritdoc IMaintenance
   */
  function totalSchedules() public view override returns (uint256 count) {
    (address[] memory validators, , ) = IRoninValidatorSet(getContract(ContractType.VALIDATOR)).getValidators();
    unchecked {
      for (uint i = 0; i < validators.length; i++) {
        if (checkScheduled(validators[i])) {
          count++;
        }
      }
    }
  }

  /**
   * @inheritdoc IMaintenance
   */
  function checkMaintained(address consensusAddr, uint256 atBlock) public view override returns (bool) {
    Schedule storage _s = _schedule[consensusAddr];
    return _s.from <= atBlock && atBlock <= _s.to;
  }

  /**
   * @inheritdoc IMaintenance
   */
  function checkMaintainedInBlockRange(
    address consensusAddr,
    uint256 fromBlock,
    uint256 toBlock
  ) public view override returns (bool) {
    return _maintainingInBlockRange(consensusAddr, fromBlock, toBlock);
  }

  /**
   * @inheritdoc IMaintenance
   */
  function checkScheduled(address consensusAddr) public view override returns (bool) {
    return block.number <= _schedule[consensusAddr].to;
  }

  /**
   * @inheritdoc IMaintenance
   */
  function checkCooldownEnds(address consensusAddr) public view override returns (bool) {
    return block.timestamp > _schedule[consensusAddr].requestTimestamp + _cooldownSecsToMaintain;
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
    uint256 minMaintenanceDurationInBlock_,
    uint256 maxMaintenanceDurationInBlock_,
    uint256 minOffsetToStartSchedule_,
    uint256 maxOffsetToStartSchedule_,
    uint256 maxSchedules_,
    uint256 cooldownSecsToMaintain_
  ) internal {
    if (_minMaintenanceDurationInBlock >= _maxMaintenanceDurationInBlock) revert ErrInvalidMaintenanceDurationConfig();
    if (_minOffsetToStartSchedule >= _maxOffsetToStartSchedule) revert ErrInvalidOffsetToStartScheduleConfigs();

    _minMaintenanceDurationInBlock = minMaintenanceDurationInBlock_;
    _maxMaintenanceDurationInBlock = maxMaintenanceDurationInBlock_;
    _minOffsetToStartSchedule = minOffsetToStartSchedule_;
    _maxOffsetToStartSchedule = maxOffsetToStartSchedule_;
    _maxSchedules = maxSchedules_;
    _cooldownSecsToMaintain = cooldownSecsToMaintain_;
    emit MaintenanceConfigUpdated(
      minMaintenanceDurationInBlock_,
      maxMaintenanceDurationInBlock_,
      minOffsetToStartSchedule_,
      maxOffsetToStartSchedule_,
      maxSchedules_,
      cooldownSecsToMaintain_
    );
  }

  /**
   * @dev Check if the validator was maintaining in the current period.
   *
   * Note: This method should be called at the end of the period.
   */
  function _maintainingInBlockRange(
    address consensusAddr,
    uint256 fromBlock,
    uint256 toBlock
  ) private view returns (bool) {
    Schedule storage s = _schedule[consensusAddr];
    return Math.twoRangeOverlap(fromBlock, toBlock, s.from, s.to);
  }
}
