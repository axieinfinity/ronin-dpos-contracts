// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "../../extensions/RONTransferHelper.sol";
import "../../extensions/collections/HasStakingVestingContract.sol";
import "../../extensions/collections/HasStakingContract.sol";
import "../../extensions/collections/HasSlashIndicatorContract.sol";
import "../../extensions/collections/HasMaintenanceContract.sol";
import "../../extensions/collections/HasRoninTrustedOrganizationContract.sol";
import "../../interfaces/IRoninValidatorSet.sol";
import "../../libraries/Sorting.sol";
import "../../libraries/Math.sol";
import "../../libraries/EnumFlags.sol";
import "../../precompile-usages/PrecompileUsageSortValidators.sol";
import "../../precompile-usages/PrecompileUsagePickValidatorSet.sol";
import "./CandidateManager.sol";

contract RoninValidatorSet is
  IRoninValidatorSet,
  PrecompileUsageSortValidators,
  PrecompileUsagePickValidatorSet,
  RONTransferHelper,
  HasStakingContract,
  HasStakingVestingContract,
  HasSlashIndicatorContract,
  HasMaintenanceContract,
  HasRoninTrustedOrganizationContract,
  CandidateManager,
  Initializable
{
  using EnumFlags for EnumFlags.ValidatorFlag;

  /// @dev The address of the precompile of sorting validators
  address internal constant _precompileSortValidatorsAddress = address(0x66);
  /// @dev The address of the precompile of picking new validator set
  address internal constant _precompilePickValidatorSetAddress = address(0x68);
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
  mapping(uint256 => address) internal _validators;
  /// @dev Mapping from address => flag indicating the validator ability: producing block, operating bridge
  mapping(address => EnumFlags.ValidatorFlag) internal _validatorMap;
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
  /// @dev Mapping from validator address => pending reward for being bridge operator
  mapping(address => uint256) internal _bridgeOperatingReward;

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
    address __roninTrustedOrganizationContract,
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
    _setRoninTrustedOrganizationContract(__roninTrustedOrganizationContract);
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

    (uint256 _validatorStakingVesting, uint256 _bridgeValidatorStakingVesting) = _stakingVestingContract.requestBonus();
    uint256 _reward = _submittedReward + _validatorStakingVesting;

    IStaking _staking = IStaking(_stakingContract);
    uint256 _rate = _candidateInfo[_coinbaseAddr].commissionRate;
    uint256 _miningAmount = (_rate * _reward) / 100_00;
    uint256 _delegatingAmount = _reward - _miningAmount;

    _miningReward[_coinbaseAddr] += _miningAmount;
    _delegatingReward[_coinbaseAddr] += _delegatingAmount;
    _bridgeOperatingReward[_coinbaseAddr] += _bridgeValidatorStakingVesting;
    _staking.recordReward(_coinbaseAddr, _delegatingAmount);
    emit BlockRewardSubmitted(_coinbaseAddr, _submittedReward, _validatorStakingVesting);
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

    address[] memory _currentValidators = getValidators();
    uint256 _period = periodOf(block.number);
    bool _periodEnding = periodEndingAt(block.number);

    uint256 _delegatingAmount = _distributeBonusAndCalculateDelegatingAmount(
      _currentValidators,
      _period,
      _periodEnding
    );

    if (_periodEnding) {
      _settleAndTransferStakingReward(_currentValidators, _delegatingAmount);
      _currentValidators = _syncValidatorSet();
    }

    _deactivateUnsatisfiedBlockProducers(_currentValidators);

    emit WrappedUpEpoch(_periodEnding);
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
  function getLastUpdatedBlock() external view returns (uint256) {
    return _lastUpdatedBlock;
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function getValidators() public view override returns (address[] memory _validatorList) {
    _validatorList = new address[](validatorCount);
    for (uint _i = 0; _i < _validatorList.length; _i++) {
      _validatorList[_i] = _validators[_i];
    }
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function isValidator(address _addr) public view override returns (bool) {
    return !_validatorMap[_addr].hasFlag(EnumFlags.ValidatorFlag.None);
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function getBlockProducers() public view override returns (address[] memory _result) {
    _result = new address[](validatorCount);
    uint256 _count = 0;
    for (uint _i = 0; _i < _result.length; _i++) {
      if (isBlockProducer(_validators[_i])) {
        _result[_count++] = _validators[_i];
      }
    }

    assembly {
      mstore(_result, _count)
    }
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function isBlockProducer(address _addr) public view override returns (bool) {
    return _validatorMap[_addr].hasFlag(EnumFlags.ValidatorFlag.BlockProducer);
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function totalBlockProducers() external view returns (uint256 _total) {
    for (uint _i = 0; _i < validatorCount; _i++) {
      if (isBlockProducer(_validators[_i])) {
        _total++;
      }
    }
  }

  /**
   * Notice: A validator is always a bride operator
   *
   * @inheritdoc IRoninValidatorSet
   */
  function getBridgeOperators() public view override returns (address[] memory _bridgeOperatorList) {
    return getValidators();
  }

  /**
   * Notice: A validator is always a bride operator
   *
   * @inheritdoc IRoninValidatorSet
   */
  function isBridgeOperator(address _addr) public view override returns (bool) {
    return isValidator(_addr);
  }

  /**
   * Notice: A validator is always a bride operator
   *
   * @inheritdoc IRoninValidatorSet
   */
  function totalBridgeOperators() external view returns (uint256) {
    return validatorCount;
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
   * @inheritdoc PrecompileUsageSortValidators
   */
  function precompileSortValidatorsAddress() public pure override returns (address) {
    return _precompileSortValidatorsAddress;
  }

  /**
   * @inheritdoc PrecompileUsagePickValidatorSet
   */
  function precompilePickValidatorSet() public pure override returns (address) {
    return _precompilePickValidatorSetAddress;
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

  ///////////////////////////////////////////////////////////////////////////////////////
  //                         HELPER FUNCTIONS OF WRAPPING UP EPOCH                     //
  ///////////////////////////////////////////////////////////////////////////////////////

  function _distributeBonusAndCalculateDelegatingAmount(
    address[] memory _currentValidators,
    uint256 _period,
    bool _periodEnding
  ) private returns (uint256 _delegatingAmount) {
    for (uint _i = 0; _i < _currentValidators.length; _i++) {
      address _validatorAddr = _currentValidators[_i];

      if (_jailed(_validatorAddr) || _rewardDeprecated(_validatorAddr, _period)) {
        continue;
      }

      if (_periodEnding) {
        _distributeBonus(_validatorAddr);
      }

      _delegatingAmount += _delegatingReward[_validatorAddr];
      delete _delegatingReward[_validatorAddr];
    }
  }

  /**
   * @dev Distribute bonus of staking vesting for block producer and bonus for bridge oparators to the treasury address
   * of the validator
   */
  function _distributeBonus(address _validatorAddr) private {
    uint256 _miningAmount = _miningReward[_validatorAddr];
    delete _miningReward[_validatorAddr];
    if (_miningAmount > 0) {
      address payable _treasury = _candidateInfo[_validatorAddr].treasuryAddr;
      require(_sendRON(_treasury, _miningAmount), "RoninValidatorSet: could not transfer RON treasury address");
      emit MiningRewardDistributed(_validatorAddr, _treasury, _miningAmount);
    }

    uint256 _bridgeOperatingAmount = _bridgeOperatingReward[_validatorAddr];
    delete _bridgeOperatingReward[_validatorAddr];
    if (_bridgeOperatingAmount > 0) {
      address payable _treasury = _candidateInfo[_validatorAddr].treasuryAddr;
      require(
        _sendRON(_treasury, _bridgeOperatingAmount),
        "RoninValidatorSet: could not transfer RON to bridge operator address"
      );
      emit BridgeOperatorRewardDistributed(_validatorAddr, _treasury, _bridgeOperatingAmount);
    }
  }

  function _settleAndTransferStakingReward(address[] memory _currentValidators, uint256 _delegatingAmount) private {
    IStaking _staking = IStaking(_stakingContract);

    _staking.settleRewardPools(_currentValidators);
    if (_delegatingAmount > 0) {
      require(
        _sendRON(payable(address(_staking)), _delegatingAmount),
        "RoninValidatorSet: could not transfer RON to staking contract"
      );
      emit StakingRewardDistributed(_delegatingAmount);
    }
  }

  /**
   * @dev Updates the validator set based on the validator candidates from the Staking contract.
   *
   * Emits the `ValidatorSetUpdated` event.
   *
   */
  function _syncValidatorSet() internal virtual returns (address[] memory _newValidators) {
    uint256[] memory _balanceWeights;
    // This is a temporary approach since the slashing issue is still not finalized.
    // Read more about slashing issue at: https://www.notion.so/skymavis/Slashing-Issue-9610ae1452434faca1213ab2e1d7d944
    uint256 _minBalance = _stakingContract.minValidatorBalance();
    _balanceWeights = _filterUnsatisfiedCandidates(_minBalance);
    uint256[] memory _trustedWeights = _roninTrustedOrganizationContract.getWeights(_candidates);
    uint256 _newValidatorCount;
    (_newValidators, _newValidatorCount) = _pickValidatorSet(
      _candidates,
      _balanceWeights,
      _trustedWeights,
      _maxValidatorNumber,
      _maxPrioritizedValidatorNumber
    );
    _setNewValidatorSet(_newValidators, _newValidatorCount);
  }

  function _setNewValidatorSet(address[] memory _newValidators, uint256 _newValidatorCount) private {
    for (uint256 _i = _newValidatorCount; _i < validatorCount; _i++) {
      delete _validatorMap[_validators[_i]];
      delete _validators[_i];
    }

    uint256 _count;
    for (uint256 _i = 0; _i < _newValidatorCount; _i++) {
      address _newValidator = _newValidators[_i];
      if (_newValidator == _validators[_count]) {
        _count++;
        continue;
      }

      delete _validatorMap[_validators[_count]];
      _validatorMap[_newValidator] = EnumFlags.ValidatorFlag.Both;
      _validators[_count] = _newValidator;
      _count++;
    }

    validatorCount = _count;
    emit ValidatorSetUpdated(_newValidators);
  }

  /**
   * @dev Deactivate the validators, who are either in jail or are under maintainance, from producing blocks
   */
  function _deactivateUnsatisfiedBlockProducers(address[] memory _currentValidators) private {
    bool[] memory _maintainingList = _maintenanceContract.bulkMaintaining(_candidates, block.number + 1);

    // for (uint _i = 0; _i < _validators.length; _i++) {}

    // TODO: filter jail
    // TODO: filter maintaining
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                             OTHER HELPER FUNCTIONS                                //
  ///////////////////////////////////////////////////////////////////////////////////////

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
