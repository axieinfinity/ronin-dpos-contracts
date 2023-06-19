// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/IMaintenance.sol";
import "../interfaces/IProfile.sol";
import "../interfaces/validator/IRoninValidatorSet.sol";
import "../extensions/collections/HasContracts.sol";
import "../libraries/Math.sol";
import { HasValidatorDeprecated } from "../utils/DeprecatedSlots.sol";
import { ErrUnauthorized, RoleAccess } from "../utils/CommonErrors.sol";

contract Maintenance is IMaintenance, HasContracts, HasValidatorDeprecated, Initializable {
  using Math for uint256;

  /// @dev Mapping from candidate id => maintenance schedule.
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

  function initializeV3(address profileContract_) external reinitializer(3) {
    _setContract(ContractType.PROFILE, profileContract_);
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
  function schedule(TConsensus consensusAddr, uint256 startedAtBlock, uint256 endedAtBlock) external override {
    IRoninValidatorSet validatorContract = IRoninValidatorSet(getContract(ContractType.VALIDATOR));
    address candidateId = _convertC2P(consensusAddr);

    if (!validatorContract.isBlockProducer(consensusAddr)) revert ErrUnauthorized(msg.sig, RoleAccess.BLOCK_PRODUCER);
    if (!validatorContract.isCandidateAdmin(consensusAddr, msg.sender))
      revert ErrUnauthorized(msg.sig, RoleAccess.CANDIDATE_ADMIN);
    if (_checkScheduledById(candidateId)) revert ErrAlreadyScheduled();
    if (!_checkCooldownEndsById(candidateId)) revert ErrCooldownTimeNotYetEnded();
    if (totalSchedules() >= _maxSchedules) revert ErrTotalOfSchedulesExceeded();
    if (!startedAtBlock.inRange(block.number + _minOffsetToStartSchedule, block.number + _maxOffsetToStartSchedule)) {
      revert ErrStartBlockOutOfRange();
    }
    if (startedAtBlock >= endedAtBlock) revert ErrStartBlockOutOfRange();

    uint256 maintenanceElapsed = endedAtBlock - startedAtBlock + 1;

    if (!maintenanceElapsed.inRange(_minMaintenanceDurationInBlock, _maxMaintenanceDurationInBlock)) {
      revert ErrInvalidMaintenanceDuration();
    }
    if (!validatorContract.epochEndingAt(startedAtBlock - 1)) revert ErrStartBlockOutOfRange();
    if (!validatorContract.epochEndingAt(endedAtBlock)) revert ErrEndBlockOutOfRange();

    Schedule storage _sSchedule = _schedule[candidateId];
    _sSchedule.from = startedAtBlock;
    _sSchedule.to = endedAtBlock;
    _sSchedule.lastUpdatedBlock = block.number;
    _sSchedule.requestTimestamp = block.timestamp;
    emit MaintenanceScheduled(consensusAddr, _sSchedule);
  }

  /**
   * @inheritdoc IMaintenance
   */
  function cancelSchedule(TConsensus consensusAddr) external override {
    if (!IRoninValidatorSet(getContract(ContractType.VALIDATOR)).isCandidateAdmin(consensusAddr, msg.sender)) {
      revert ErrUnauthorized(msg.sig, RoleAccess.CANDIDATE_ADMIN);
    }

    address candidateId = _convertC2P(consensusAddr);

    if (!_checkScheduledById(candidateId)) revert ErrUnexistedSchedule();
    if (_checkMaintainedById(candidateId, block.number)) revert ErrAlreadyOnMaintenance();

    Schedule storage _sSchedule = _schedule[candidateId];
    delete _sSchedule.from;
    delete _sSchedule.to;
    _sSchedule.lastUpdatedBlock = block.number;
    emit MaintenanceScheduleCancelled(consensusAddr);
  }

  /**
   * @inheritdoc IMaintenance
   */
  function getSchedule(TConsensus consensusAddr) external view override returns (Schedule memory) {
    return _schedule[_convertC2P(consensusAddr)];
  }

  /**
   * @inheritdoc IMaintenance
   */
  function checkManyMaintained(
    TConsensus[] calldata addrList,
    uint256 atBlock
  ) external view override returns (bool[] memory) {
    address[] memory idList = _convertManyC2P(addrList);
    return _checkManyMaintainedById(idList, atBlock);
  }

  function checkManyMaintainedById(
    address[] calldata idList,
    uint256 atBlock
  ) external view override returns (bool[] memory) {
    return _checkManyMaintainedById(idList, atBlock);
  }

  function _checkManyMaintainedById(
    address[] memory idList,
    uint256 atBlock
  ) internal view returns (bool[] memory resList) {
    resList = new bool[](idList.length);
    for (uint i = 0; i < idList.length; ) {
      resList[i] = _checkMaintainedById(idList[i], atBlock);

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @inheritdoc IMaintenance
   */
  function checkManyMaintainedInBlockRange(
    TConsensus[] calldata addrList,
    uint256 fromBlock,
    uint256 toBlock
  ) external view override returns (bool[] memory) {
    address[] memory idList = _convertManyC2P(addrList);
    return _checkManyMaintainedInBlockRangeById(idList, fromBlock, toBlock);
  }

  function checkManyMaintainedInBlockRangeById(
    address[] calldata idList,
    uint256 fromBlock,
    uint256 toBlock
  ) external view override returns (bool[] memory) {
    return _checkManyMaintainedInBlockRangeById(idList, fromBlock, toBlock);
  }

  function _checkManyMaintainedInBlockRangeById(
    address[] memory idList,
    uint256 fromBlock,
    uint256 toBlock
  ) internal view returns (bool[] memory resList) {
    resList = new bool[](idList.length);
    for (uint i = 0; i < idList.length; ) {
      resList[i] = _maintainingInBlockRange(idList[i], fromBlock, toBlock);

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @inheritdoc IMaintenance
   */
  function totalSchedules() public view override returns (uint256 count) {
    (, , , address[] memory validatorIds) = IRoninValidatorSet(getContract(ContractType.VALIDATOR)).getValidators();
    unchecked {
      for (uint i = 0; i < validatorIds.length; i++) {
        if (_checkScheduledById(validatorIds[i])) {
          count++;
        }
      }
    }
  }

  /**
   * @inheritdoc IMaintenance
   */
  function checkMaintained(TConsensus consensusAddr, uint256 atBlock) external view override returns (bool) {
    return _checkMaintainedById(_convertC2P(consensusAddr), atBlock);
  }

  function checkMaintainedById(address candidateId, uint256 atBlock) external view override returns (bool) {
    return _checkMaintainedById(candidateId, atBlock);
  }

  function _checkMaintainedById(address candidateId, uint256 atBlock) internal view returns (bool) {
    Schedule storage _s = _schedule[candidateId];
    return _s.from <= atBlock && atBlock <= _s.to;
  }

  /**
   * @inheritdoc IMaintenance
   */
  function checkMaintainedInBlockRange(
    TConsensus consensusAddr,
    uint256 fromBlock,
    uint256 toBlock
  ) public view override returns (bool) {
    return _maintainingInBlockRange(_convertC2P(consensusAddr), fromBlock, toBlock);
  }

  /**
   * @inheritdoc IMaintenance
   */
  function checkScheduled(TConsensus consensusAddr) external view override returns (bool) {
    return _checkScheduledById(_convertC2P(consensusAddr));
  }

  function _checkScheduledById(address candidateId) internal view returns (bool) {
    return block.number <= _schedule[candidateId].to;
  }

  /**
   * @inheritdoc IMaintenance
   */
  function checkCooldownEnds(TConsensus consensusAddr) external view override returns (bool) {
    return _checkCooldownEndsById(_convertC2P(consensusAddr));
  }

  function _checkCooldownEndsById(address candidateId) internal view returns (bool) {
    return block.timestamp > _schedule[candidateId].requestTimestamp + _cooldownSecsToMaintain;
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
    if (minMaintenanceDurationInBlock_ >= maxMaintenanceDurationInBlock_) revert ErrInvalidMaintenanceDurationConfig();
    if (minOffsetToStartSchedule_ >= maxOffsetToStartSchedule_) revert ErrInvalidOffsetToStartScheduleConfigs();

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
    address candidateId,
    uint256 fromBlock,
    uint256 toBlock
  ) private view returns (bool) {
    Schedule storage s = _schedule[candidateId];
    return Math.twoRangeOverlap(fromBlock, toBlock, s.from, s.to);
  }

  function _convertC2P(TConsensus consensusAddr) internal view returns (address) {
    return IProfile(getContract(ContractType.PROFILE)).getConsensus2Id(consensusAddr);
  }

  function _convertManyC2P(TConsensus[] memory consensusAddrs) internal view returns (address[] memory) {
    return IProfile(getContract(ContractType.PROFILE)).getManyConsensus2Id(consensusAddrs);
  }
}
