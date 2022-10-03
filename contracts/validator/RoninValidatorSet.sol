// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "../extensions/RONTransferHelper.sol";
import "../extensions/HasStakingVestingContract.sol";
import "../extensions/HasStakingContract.sol";
import "../extensions/HasSlashIndicatorContract.sol";
import "../extensions/HasMaintenanceContract.sol";
import "../interfaces/IRoninValidatorSet.sol";
import "../libraries/Sorting.sol";
import "../libraries/Math.sol";
import "./CandidateManager.sol";

contract RoninValidatorSet is
  IRoninValidatorSet,
  RONTransferHelper,
  HasStakingContract,
  HasStakingVestingContract,
  HasSlashIndicatorContract,
  HasMaintenanceContract,
  CandidateManager,
  Initializable
{
  /// @dev The maximum number of validator.
  uint256 internal _maxValidatorNumber;
  /// @dev The number of blocks in a epoch
  uint256 internal _numberOfBlocksInEpoch;
  /// @dev Returns the number of epochs in a period
  uint256 internal _numberOfEpochsInPeriod;
  /// @dev The last updated block
  uint256 internal _lastUpdatedBlock;

  /// @dev The total of validators
  uint256 public validatorCount;
  /// @dev Mapping from validator index => validator address
  mapping(uint256 => address) internal _validator;
  /// @dev Mapping from address => flag indicating whether the address is validator or not
  mapping(address => bool) internal _validatorMap;

  /// @dev Mapping from address => flag indicating whether the address is prioritized to be a validator
  mapping(address => bool) internal _prioritizedRegisterredMap;
  /// @dev The number of slot that is reserved for prioritized validators
  uint256 internal _maxPrioritizedValidatorNumber;

  /// @dev Mapping from validator address => the last period that the validator has no pending reward
  mapping(address => mapping(uint256 => bool)) internal _rewardDeprecatedAtPeriod;
  /// @dev Mapping from validator address => the last block that the validator is jailed
  mapping(address => uint256) internal _jailedUntil;

  /// @dev Mapping from validator address => pending reward from producing block
  mapping(address => uint256) internal _miningReward;
  /// @dev Mapping from validator address => pending reward from delegating
  mapping(address => uint256) internal _delegatingReward;

  modifier onlyCoinbase() {
    require(msg.sender == block.coinbase, "RoninValidatorSet: method caller must be coinbase");
    _;
  }

  modifier whenEpochEnding() {
    require(epochEndingAt(block.number), "RoninValidatorSet: only allowed at the end of epoch");
    _;
  }

  constructor() {
    _disableInitializers();
  }

  fallback() external payable {
    _fallback();
  }

  receive() external payable {
    _fallback();
  }

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(
    address __slashIndicatorContract,
    address __stakingContract,
    address __stakingVestingContract,
    address __maintenanceContract,
    uint256 __maxValidatorNumber,
    uint256 __maxValidatorCandidate,
    uint256 __maxPrioritizedValidatorNumber,
    uint256 __numberOfBlocksInEpoch,
    uint256 __numberOfEpochsInPeriod
  ) external initializer {
    _setSlashIndicatorContract(__slashIndicatorContract);
    _setStakingContract(__stakingContract);
    _setStakingVestingContract(__stakingVestingContract);
    _setMaintenanceContract(__maintenanceContract);
    _setMaxValidatorNumber(__maxValidatorNumber);
    _setMaxValidatorCandidate(__maxValidatorCandidate);
    _setPrioritizedValidatorNumber(__maxPrioritizedValidatorNumber);
    _setNumberOfBlocksInEpoch(__numberOfBlocksInEpoch);
    _setNumberOfEpochsInPeriod(__numberOfEpochsInPeriod);
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                              FUNCTIONS FOR COINBASE                               //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function submitBlockReward() external payable override onlyCoinbase {
    uint256 _submittedReward = msg.value;
    if (_submittedReward == 0) {
      return;
    }

    address _coinbaseAddr = msg.sender;
    // Deprecates reward for non-validator or slashed validator
    if (
      !isValidator(_coinbaseAddr) || _jailed(_coinbaseAddr) || _rewardDeprecated(_coinbaseAddr, periodOf(block.number))
    ) {
      emit RewardDeprecated(_coinbaseAddr, _submittedReward);
      return;
    }

    uint256 _bonusReward = _stakingVestingContract.requestBlockBonus();
    uint256 _reward = _submittedReward + _bonusReward;

    IStaking _staking = IStaking(_stakingContract);
    uint256 _rate = _candidateInfo[_coinbaseAddr].commissionRate;
    uint256 _miningAmount = (_rate * _reward) / 100_00;
    uint256 _delegatingAmount = _reward - _miningAmount;

    _miningReward[_coinbaseAddr] += _miningAmount;
    _delegatingReward[_coinbaseAddr] += _delegatingAmount;
    _staking.recordReward(_coinbaseAddr, _delegatingAmount);
    emit BlockRewardSubmitted(_coinbaseAddr, _submittedReward, _bonusReward);
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function wrapUpEpoch() external payable virtual override onlyCoinbase whenEpochEnding {
    require(
      epochOf(_lastUpdatedBlock) < epochOf(block.number),
      "RoninValidatorSet: query for already wrapped up epoch"
    );
    _lastUpdatedBlock = block.number;

    IStaking _staking = IStaking(_stakingContract);
    address _validatorAddr;
    uint256 _delegatingAmount;
    uint256 _period = periodOf(block.number);
    bool _periodEnding = periodEndingAt(block.number);

    address[] memory _validators = getValidators();
    for (uint _i = 0; _i < _validators.length; _i++) {
      _validatorAddr = _validators[_i];

      if (_jailed(_validatorAddr) || _rewardDeprecated(_validatorAddr, _period)) {
        continue;
      }

      if (_periodEnding) {
        uint256 _miningAmount = _miningReward[_validatorAddr];
        delete _miningReward[_validatorAddr];
        if (_miningAmount > 0) {
          address payable _treasury = _candidateInfo[_validatorAddr].treasuryAddr;
          require(_sendRON(_treasury, _miningAmount), "RoninValidatorSet: could not transfer RON treasury address");
          emit MiningRewardDistributed(_validatorAddr, _miningAmount);
        }
      }

      _delegatingAmount += _delegatingReward[_validatorAddr];
      delete _delegatingReward[_validatorAddr];
    }

    if (_periodEnding) {
      _staking.settleRewardPools(_validators);
      if (_delegatingAmount > 0) {
        require(
          _sendRON(payable(address(_staking)), 0),
          "RoninValidatorSet: could not transfer RON to staking contract"
        );
        emit StakingRewardDistributed(_delegatingAmount);
      }
    }

    _updateValidatorSet(_periodEnding);
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function getLastUpdatedBlock() external view returns (uint256) {
    return _lastUpdatedBlock;
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                            FUNCTIONS FOR SLASH INDICATOR                          //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function slash(
    address _validatorAddr,
    uint256 _newJailedUntil,
    uint256 _slashAmount
  ) external onlySlashIndicatorContract {
    _rewardDeprecatedAtPeriod[_validatorAddr][periodOf(block.number)] = true;
    delete _miningReward[_validatorAddr];
    delete _delegatingReward[_validatorAddr];
    IStaking(_stakingContract).sinkPendingReward(_validatorAddr);

    if (_newJailedUntil > 0) {
      _jailedUntil[_validatorAddr] = Math.max(_newJailedUntil, _jailedUntil[_validatorAddr]);
    }

    if (_slashAmount > 0) {
      IStaking(_stakingContract).deductStakedAmount(_validatorAddr, _slashAmount);
    }

    emit ValidatorPunished(_validatorAddr, _jailedUntil[_validatorAddr], _slashAmount);
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function jailed(address[] memory _addrList) external view override returns (bool[] memory _result) {
    for (uint256 _i; _i < _addrList.length; _i++) {
      _result[_i] = _jailed(_addrList[_i]);
    }
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function rewardDeprecated(address[] memory _addrList, uint256 _period)
    external
    view
    override
    returns (bool[] memory _result)
  {
    for (uint256 _i; _i < _addrList.length; _i++) {
      _result[_i] = _rewardDeprecated(_addrList[_i], _period);
    }
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                             FUNCTIONS FOR NORMAL USER                             //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function epochOf(uint256 _block) public view virtual override returns (uint256) {
    return _block == 0 ? 0 : _block / _numberOfBlocksInEpoch + 1;
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function periodOf(uint256 _block) public view virtual override returns (uint256) {
    return _block == 0 ? 0 : _block / (_numberOfBlocksInEpoch * _numberOfEpochsInPeriod) + 1;
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function getValidators() public view override returns (address[] memory _validatorList) {
    _validatorList = new address[](validatorCount);
    for (uint _i = 0; _i < _validatorList.length; _i++) {
      _validatorList[_i] = _validator[_i];
    }
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function isValidator(address _addr) public view returns (bool) {
    return _validatorMap[_addr];
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function epochEndingAt(uint256 _block) public view virtual returns (bool) {
    return _block % _numberOfBlocksInEpoch == _numberOfBlocksInEpoch - 1;
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function periodEndingAt(uint256 _block) public view virtual returns (bool) {
    uint256 _blockLength = _numberOfBlocksInEpoch * _numberOfEpochsInPeriod;
    return _block % _blockLength == _blockLength - 1;
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function numberOfEpochsInPeriod()
    public
    view
    override(CandidateManager, ICandidateManager)
    returns (uint256 _numberOfEpochs)
  {
    return _numberOfEpochsInPeriod;
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function numberOfBlocksInEpoch()
    public
    view
    override(CandidateManager, ICandidateManager)
    returns (uint256 _numberOfBlocks)
  {
    return _numberOfBlocksInEpoch;
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function maxValidatorNumber() external view override returns (uint256 _maximumValidatorNumber) {
    return _maxValidatorNumber;
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function maxPrioritizedValidatorNumber() external view override returns (uint256 _maximumPrioritizedValidatorNumber) {
    return _maxPrioritizedValidatorNumber;
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function getPriorityStatus(address _addr) external view override returns (bool) {
    return _prioritizedRegisterredMap[_addr];
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                               FUNCTIONS FOR ADMIN                                 //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function setMaxValidatorNumber(uint256 _max) external override onlyAdmin {
    _setMaxValidatorNumber(_max);
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function setNumberOfBlocksInEpoch(uint256 _number) external override onlyAdmin {
    _setNumberOfBlocksInEpoch(_number);
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function setNumberOfEpochsInPeriod(uint256 _number) external override onlyAdmin {
    _setNumberOfEpochsInPeriod(_number);
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function setPrioritizedAddresses(address[] memory _addrs, bool[] memory _statuses) external override onlyAdmin {
    require(_addrs.length != 0, "RoninValidatorSet: empty array");
    require(_addrs.length == _statuses.length, "RoninValidatorSet: length of two input arrays mismatches");

    for (uint _i = 0; _i < _addrs.length; _i++) {
      if (_prioritizedRegisterredMap[_addrs[_i]] != _statuses[_i]) {
        _prioritizedRegisterredMap[_addrs[_i]] = _statuses[_i];
      }
    }

    emit AddressesPriorityStatusUpdated(_addrs, _statuses);
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                                  HELPER FUNCTIONS                                 //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Returns validator candidates list.
   */
  function _syncNewValidatorSet(bool _periodEnding) internal returns (address[] memory _candidateList) {
    // This is a temporary approach since the slashing issue is still not finalized.
    // Read more about slashing issue at: https://www.notion.so/skymavis/Slashing-Issue-9610ae1452434faca1213ab2e1d7d944
    uint256 _minBalance = _stakingContract.minValidatorBalance();
    uint256[] memory _weights = _filterUnsatisfiedCandidates(_periodEnding ? _minBalance : 0);
    _candidateList = _candidates;

    uint256 _length = _candidateList.length;
    for (uint256 _i; _i < _candidateList.length; _i++) {
      if (_jailed(_candidateList[_i]) || _weights[_i] < _minBalance) {
        _length--;
        _candidateList[_i] = _candidateList[_length];
        _weights[_i] = _weights[_length];
      }
    }

    assembly {
      mstore(_candidateList, _length)
      mstore(_weights, _length)
    }

    _candidateList = Sorting.sort(_candidateList, _weights);
  }

  /**
   * @dev Updates the validator set based on the validator candidates from the Staking contract.
   *
   * Emits the `ValidatorSetUpdated` event.
   *
   */
  function _updateValidatorSet(bool _periodEnding) internal virtual {
    address[] memory _candidates = _syncNewValidatorSet(_periodEnding);
    uint256 _newValidatorCount = Math.min(_maxValidatorNumber, _candidates.length);
    _arrangeValidatorCandidates(_candidates, _newValidatorCount);

    assembly {
      mstore(_candidates, _newValidatorCount)
    }

    for (uint256 _i = _newValidatorCount; _i < validatorCount; _i++) {
      delete _validatorMap[_validator[_i]];
      delete _validator[_i];
    }

    uint256 _count;
    bool[] memory _maintainingList = _maintenanceContract.bulkMaintaining(_candidates, block.number + 1);
    for (uint256 _i = 0; _i < _newValidatorCount; _i++) {
      if (_maintainingList[_i]) {
        continue;
      }

      address _newValidator = _candidates[_i];
      if (_newValidator == _validator[_count]) {
        _count++;
        continue;
      }

      delete _validatorMap[_validator[_count]];
      _validatorMap[_newValidator] = true;
      _validator[_count] = _newValidator;
      _count++;
    }

    validatorCount = _count;
    emit ValidatorSetUpdated(_candidates);
  }

  /**
   * @dev Returns whether the reward of the validator is put in jail (cannot join the set of validators) during the current period.
   */
  function _jailed(address _validatorAddr) internal view returns (bool) {
    return block.number <= _jailedUntil[_validatorAddr];
  }

  /**
   * @dev Returns whether the validator has no pending reward in that period.
   */
  function _rewardDeprecated(address _validatorAddr, uint256 _period) internal view returns (bool) {
    return _rewardDeprecatedAtPeriod[_validatorAddr][_period];
  }

  /**
   * @dev Returns whether the address `_addr` is validator or not.
   */
  function _isValidator(address _addr) internal view returns (bool) {
    return _validatorMap[_addr];
  }

  /**
   * @dev Arranges the sorted candidates to list of validators, by asserting prioritized and non-prioritized candidates
   *
   * @param _candidates A sorted list of candidates
   */
  function _arrangeValidatorCandidates(address[] memory _candidates, uint _newValidatorCount) internal view {
    address[] memory _waitingCandidates = new address[](_candidates.length);
    uint _waitingCounter;
    uint _prioritySlotCounter;

    for (uint _i = 0; _i < _candidates.length; _i++) {
      if (_prioritizedRegisterredMap[_candidates[_i]]) {
        if (_prioritySlotCounter < _maxPrioritizedValidatorNumber) {
          _candidates[_prioritySlotCounter++] = _candidates[_i];
          continue;
        }
      }
      _waitingCandidates[_waitingCounter++] = _candidates[_i];
    }

    _waitingCounter = 0;
    for (uint _i = _prioritySlotCounter; _i < _newValidatorCount; _i++) {
      _candidates[_i] = _waitingCandidates[_waitingCounter++];
    }
  }

  /**
   * @dev Updates the max validator number
   *
   * Emits the event `MaxValidatorNumberUpdated`
   *
   */
  function _setMaxValidatorNumber(uint256 _number) internal {
    _maxValidatorNumber = _number;
    emit MaxValidatorNumberUpdated(_number);
  }

  /**
   * @dev Updates the number of reserved slots for prioritized validators
   */
  function _setPrioritizedValidatorNumber(uint256 _number) internal {
    require(
      _number <= _maxValidatorNumber,
      "RoninValidatorSet: cannot set number of prioritized greater than number of max validators"
    );

    _maxPrioritizedValidatorNumber = _number;
    emit MaxPrioritizedValidatorNumberUpdated(_number);
  }

  /**
   * @dev Updates the number of blocks in epoch
   *
   * Emits the event `NumberOfBlocksInEpochUpdated`
   *
   */
  function _setNumberOfBlocksInEpoch(uint256 _number) internal {
    _numberOfBlocksInEpoch = _number;
    emit NumberOfBlocksInEpochUpdated(_number);
  }

  /**
   * @dev Updates the number of epochs in period
   *
   * Emits the event `NumberOfEpochsInPeriodUpdated`
   *
   */
  function _setNumberOfEpochsInPeriod(uint256 _number) internal {
    _numberOfEpochsInPeriod = _number;
    emit NumberOfEpochsInPeriodUpdated(_number);
  }

  /**
   * @dev Only receives RON from staking vesting contract.
   */
  function _fallback() internal view {
    require(
      msg.sender == stakingVestingContract(),
      "RoninValidatorSet: only receives RON from staking vesting contract"
    );
  }
}
