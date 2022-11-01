// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../extensions/RONTransferHelper.sol";
import "../../extensions/collections/HasStakingVestingContract.sol";
import "../../extensions/collections/HasStakingContract.sol";
import "../../extensions/collections/HasSlashIndicatorContract.sol";
import "../../extensions/collections/HasMaintenanceContract.sol";
import "../../extensions/collections/HasRoninTrustedOrganizationContract.sol";
import "../../extensions/collections/HasBridgeTrackingContract.sol";
import "../../extensions/consumers/PercentageConsumer.sol";
import "../../interfaces/IRoninValidatorSet.sol";
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
  HasBridgeTrackingContract,
  CandidateManager,
  PercentageConsumer,
  Initializable
{
  using EnumFlags for EnumFlags.ValidatorFlag;

  /// @dev The maximum number of validator.
  uint256 internal _maxValidatorNumber;
  /// @dev The number of blocks in a epoch
  uint256 internal _numberOfBlocksInEpoch;
  /// @dev The last updated block
  uint256 internal _lastUpdatedBlock;
  /// @dev The last updated period
  uint256 internal _lastUpdatedPeriod;
  /// @dev The starting block of the last updated period
  uint256 internal _currentPeriodStartAtBlock;

  /// @dev The total of validators
  uint256 public validatorCount;
  /// @dev Mapping from validator index => validator address
  mapping(uint256 => address) internal _validators;
  /// @dev Mapping from address => flag indicating the validator ability: producing block, operating bridge
  mapping(address => EnumFlags.ValidatorFlag) internal _validatorMap;
  /// @dev The number of slot that is reserved for prioritized validators
  uint256 internal _maxPrioritizedValidatorNumber;

  /// @dev Mapping from consensus address => the last period that the block producer has no pending reward
  mapping(address => mapping(uint256 => bool)) internal _miningRewardDeprecatedAtPeriod;
  /// @dev Mapping from consensus address => the last period that the block operator has no pending reward
  mapping(address => mapping(uint256 => bool)) internal _bridgeRewardDeprecatedAtPeriod;
  /// @dev Mapping from consensus address => the last block that the validator is jailed
  mapping(address => uint256) internal _jailedUntil;

  /// @dev Mapping from consensus address => pending reward from producing block
  mapping(address => uint256) internal _miningReward;
  /// @dev Mapping from consensus address => pending reward from delegating
  mapping(address => uint256) internal _delegatingReward;

  /// @dev The total reward for bridge operators
  uint256 internal _totalBridgeReward;
  /// @dev Mapping from consensus address => pending reward for being bridge operator
  mapping(address => uint256) internal _bridgeOperatingReward;

  modifier onlyCoinbase() {
    require(msg.sender == block.coinbase, "RoninValidatorSet: method caller must be coinbase");
    _;
  }

  modifier whenEpochEnding() {
    require(epochEndingAt(block.number), "RoninValidatorSet: only allowed at the end of epoch");
    _;
  }

  modifier oncePerEpoch() {
    require(
      epochOf(_lastUpdatedBlock) < epochOf(block.number),
      "RoninValidatorSet: query for already wrapped up epoch"
    );
    _lastUpdatedBlock = block.number;
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
    address __bridgeTrackingContract,
    uint256 __maxValidatorNumber,
    uint256 __maxValidatorCandidate,
    uint256 __maxPrioritizedValidatorNumber,
    uint256 __numberOfBlocksInEpoch
  ) external initializer {
    _setSlashIndicatorContract(__slashIndicatorContract);
    _setStakingContract(__stakingContract);
    _setStakingVestingContract(__stakingVestingContract);
    _setMaintenanceContract(__maintenanceContract);
    _setBridgeTrackingContract(__bridgeTrackingContract);
    _setRoninTrustedOrganizationContract(__roninTrustedOrganizationContract);
    _setMaxValidatorNumber(__maxValidatorNumber);
    _setMaxValidatorCandidate(__maxValidatorCandidate);
    _setPrioritizedValidatorNumber(__maxPrioritizedValidatorNumber);
    _setNumberOfBlocksInEpoch(__numberOfBlocksInEpoch);
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                              FUNCTIONS FOR COINBASE                               //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function submitBlockReward() external payable override onlyCoinbase {
    uint256 _submittedReward = msg.value;
    address _coinbaseAddr = msg.sender;

    uint256 _bridgeOperatorBonus = _stakingVestingContract.requestBridgeOperatorBonus();
    _totalBridgeReward += _bridgeOperatorBonus;

    // Deprecates reward for non-validator or slashed validator
    if (
      !isBlockProducer(_coinbaseAddr) ||
      _jailed(_coinbaseAddr) ||
      _miningRewardDeprecated(_coinbaseAddr, currentPeriod())
    ) {
      emit BlockRewardRewardDeprecated(_coinbaseAddr, _submittedReward);
      return;
    }

    uint256 _blockProducerBonus = _stakingVestingContract.requestValidatorBonus();
    uint256 _reward = _submittedReward + _blockProducerBonus;
    uint256 _rate = _candidateInfo[_coinbaseAddr].commissionRate;

    uint256 _miningAmount = (_rate * _reward) / 100_00;
    _miningReward[_coinbaseAddr] += _miningAmount;

    uint256 _delegatingAmount = _reward - _miningAmount;
    _delegatingReward[_coinbaseAddr] += _delegatingAmount;
    _stakingContract.recordReward(_coinbaseAddr, _delegatingAmount);
    emit BlockRewardSubmitted(_coinbaseAddr, _submittedReward, _blockProducerBonus);
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function wrapUpEpoch() external payable virtual override onlyCoinbase whenEpochEnding oncePerEpoch {
    uint256 _newPeriod = _computePeriod(block.timestamp);
    bool _periodEnding = _isPeriodEnding(_newPeriod);

    address[] memory _currentValidators = getValidators();
    uint256 _epoch = epochOf(block.number);
    uint256 _lastPeriod = currentPeriod();

    if (_periodEnding) {
      uint256 _totalDelegatingReward = _distributeRewardToTreasuriesAndCalculateTotalDelegatingReward(
        _lastPeriod,
        _currentValidators
      );
      _settleAndTransferDelegatingRewards(_currentValidators, _totalDelegatingReward);
      _currentValidators = _syncValidatorSet(_newPeriod);
    }

    _revampBlockProducers(_newPeriod, _currentValidators);
    emit WrappedUpEpoch(_lastPeriod, _epoch, _periodEnding);
    _lastUpdatedPeriod = _newPeriod;
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
    uint256 _period = currentPeriod();
    _miningRewardDeprecatedAtPeriod[_validatorAddr][_period] = true;
    delete _miningReward[_validatorAddr];
    delete _delegatingReward[_validatorAddr];
    IStaking(_stakingContract).sinkPendingReward(_validatorAddr);

    if (_newJailedUntil > 0) {
      _jailedUntil[_validatorAddr] = Math.max(_newJailedUntil, _jailedUntil[_validatorAddr]);
    }

    if (_slashAmount > 0) {
      IStaking(_stakingContract).deductStakedAmount(_validatorAddr, _slashAmount);
    }

    emit ValidatorPunished(_validatorAddr, _period, _jailedUntil[_validatorAddr], _slashAmount, true, false);
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function bailOut(address _validatorAddr) external override onlySlashIndicatorContract {
    _jailedUntil[_validatorAddr] = block.number - 1;

    emit ValidatorLiberated(_validatorAddr);
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function jailed(address _addr) external view override returns (bool) {
    return jailedAtBlock(_addr, block.number);
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function jailedTimeLeft(address _addr)
    external
    view
    override
    returns (
      bool isJailed_,
      uint256 blockLeft_,
      uint256 epochLeft_
    )
  {
    return jailedTimeLeftAtBlock(_addr, block.number);
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function jailedAtBlock(address _addr, uint256 _blockNum) public view override returns (bool) {
    return _jailedAtBlock(_addr, _blockNum);
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function jailedTimeLeftAtBlock(address _addr, uint256 _blockNum)
    public
    view
    override
    returns (
      bool isJailed_,
      uint256 blockLeft_,
      uint256 epochLeft_
    )
  {
    uint256 __jailedUntil = _jailedUntil[_addr];
    if (__jailedUntil < _blockNum) {
      return (false, 0, 0);
    }

    isJailed_ = true;
    blockLeft_ = __jailedUntil - _blockNum + 1;
    epochLeft_ = epochOf(__jailedUntil) - epochOf(_blockNum) + 1;
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function bulkJailed(address[] memory _addrList) external view override returns (bool[] memory _result) {
    _result = new bool[](_addrList.length);
    for (uint256 _i; _i < _addrList.length; _i++) {
      _result[_i] = _jailed(_addrList[_i]);
    }
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function miningRewardDeprecated(address[] memory _blockProducers)
    external
    view
    override
    returns (bool[] memory _result)
  {
    _result = new bool[](_blockProducers.length);
    uint256 _period = currentPeriod();
    for (uint256 _i; _i < _blockProducers.length; _i++) {
      _result[_i] = _miningRewardDeprecated(_blockProducers[_i], _period);
    }
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function miningRewardDeprecatedAtPeriod(address[] memory _blockProducers, uint256 _period)
    external
    view
    override
    returns (bool[] memory _result)
  {
    _result = new bool[](_blockProducers.length);
    for (uint256 _i; _i < _blockProducers.length; _i++) {
      _result[_i] = _miningRewardDeprecated(_blockProducers[_i], _period);
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
   * @inheritdoc ICandidateManager
   */
  function currentPeriod() public view virtual override(CandidateManager, ICandidateManager) returns (uint256) {
    return _lastUpdatedPeriod;
  }

  /**
   * @inheritdoc ICandidateManager
   */
  function currentPeriodStartAtBlock() public view virtual override returns (uint256) {
    return _currentPeriodStartAtBlock;
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function getLastUpdatedBlock() external view override returns (uint256) {
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
    return !_validatorMap[_addr].isNone();
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
   * @inheritdoc IRoninValidatorSet
   */
  function getBridgeOperators() public view override returns (address[] memory _bridgeOperatorList) {
    _bridgeOperatorList = new address[](validatorCount);
    for (uint _i = 0; _i < _bridgeOperatorList.length; _i++) {
      _bridgeOperatorList[_i] = _candidateInfo[_validators[_i]].bridgeOperatorAddr;
    }
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function isBridgeOperator(address _bridgeOperatorAddr) external view override returns (bool _result) {
    for (uint _i = 0; _i < validatorCount; _i++) {
      if (_candidateInfo[_validators[_i]].bridgeOperatorAddr == _bridgeOperatorAddr) {
        _result = true;
        break;
      }
    }
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function isPeriodEnding() external view virtual returns (bool) {
    return _isPeriodEnding(_computePeriod(block.timestamp));
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function epochEndingAt(uint256 _block) public view virtual returns (bool) {
    return _block % _numberOfBlocksInEpoch == _numberOfBlocksInEpoch - 1;
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
   * Notice: A validator is always a bride operator
   *
   * @inheritdoc IRoninValidatorSet
   */
  function totalBridgeOperators() public view returns (uint256) {
    return validatorCount;
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

  ///////////////////////////////////////////////////////////////////////////////////////
  //                     PRIVATE HELPER FUNCTIONS OF WRAPPING UP EPOCH                 //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev This loop over the all current validators to:
   * - Update delegating reward for and calculate total delegating rewards to be sent to the staking contract,
   * - Distribute the reward of block producers and bridge operators to their treasury addresses.
   *
   * Note: This method should be called once in the end of each period.
   *
   */
  function _distributeRewardToTreasuriesAndCalculateTotalDelegatingReward(
    uint256 _lastPeriod,
    address[] memory _currentValidators
  ) private returns (uint256 _totalDelegatingReward) {
    address _consensusAddr;
    address payable _treasury;
    IBridgeTracking _bridgeTracking = _bridgeTrackingContract;

    uint256 _totalBridgeBallots = _bridgeTracking.totalBallots(_lastPeriod);
    uint256 _totalBridgeVotes = _bridgeTracking.totalVotes(_lastPeriod);
    uint256[] memory _bridgeBallots = _bridgeTracking.bulkTotalBallotsOf(_lastPeriod, _currentValidators);
    (
      uint256 _missingVotesRatioTier1,
      uint256 _missingVotesRatioTier2,
      uint256 _jailDurationForMissingVotesRatioTier2
    ) = _slashIndicatorContract.getBridgeOperatorSlashingConfigs();

    for (uint _i = 0; _i < _currentValidators.length; _i++) {
      _consensusAddr = _currentValidators[_i];
      _treasury = _candidateInfo[_consensusAddr].treasuryAddr;
      _updateValidatorReward(
        _lastPeriod,
        _consensusAddr,
        _bridgeBallots[_i],
        _totalBridgeVotes,
        _totalBridgeBallots,
        _missingVotesRatioTier1,
        _missingVotesRatioTier2,
        _jailDurationForMissingVotesRatioTier2
      );

      if (!_bridgeRewardDeprecated(_consensusAddr, _lastPeriod)) {
        _distributeBridgeOperatingReward(_consensusAddr, _candidateInfo[_consensusAddr].bridgeOperatorAddr, _treasury);
      }

      if (!_jailed(_consensusAddr) && !_miningRewardDeprecated(_consensusAddr, _lastPeriod)) {
        _totalDelegatingReward += _delegatingReward[_consensusAddr];
        _distributeMiningReward(_consensusAddr, _treasury);
      }

      delete _delegatingReward[_consensusAddr];
      delete _miningReward[_consensusAddr];
      delete _bridgeOperatingReward[_consensusAddr];
    }
    delete _totalBridgeReward;
  }

  /**
   * @dev Updates validator reward based on the corresponding bridge operator performance.
   */
  function _updateValidatorReward(
    uint256 _period,
    address _validator,
    uint256 _validatorBallots,
    uint256 _totalVotes,
    uint256 _totalBallots,
    uint256 _ratioTier1,
    uint256 _ratioTier2,
    uint256 _jailDurationTier2
  ) internal {
    // Shares equally in case the bridge has nothing to votes
    if (_totalBallots == 0 && _totalVotes == 0) {
      uint256 _shareRatio = _MAX_PERCENTAGE / totalBridgeOperators();
      _bridgeOperatingReward[_validator] = (_shareRatio * _totalBridgeReward) / _MAX_PERCENTAGE;
      return;
    }

    uint256 _votedRatio = (_validatorBallots * _MAX_PERCENTAGE) / _totalVotes;
    uint256 _missedRatio = _MAX_PERCENTAGE - _votedRatio;
    if (_missedRatio > _ratioTier2) {
      _bridgeRewardDeprecatedAtPeriod[_validator][_period] = true;
      _miningRewardDeprecatedAtPeriod[_validator][_period] = true;
      _jailedUntil[_validator] = Math.max(block.number + _jailDurationTier2, _jailedUntil[_validator]);
      emit ValidatorPunished(_validator, _period, _jailedUntil[_validator], 0, true, true);
    } else if (_missedRatio > _ratioTier1) {
      _bridgeRewardDeprecatedAtPeriod[_validator][_period] = true;
      emit ValidatorPunished(_validator, _period, _jailedUntil[_validator], 0, false, true);
    } else if (_totalBallots > 0) {
      uint256 _shareRatio = (_validatorBallots * _MAX_PERCENTAGE) / _totalBallots;
      _bridgeOperatingReward[_validator] = (_shareRatio * _totalBridgeReward) / _MAX_PERCENTAGE;
    }
  }

  /**
   * @dev Distributes bonus of staking vesting and mining fee for the block producer.
   *
   * Emits the `MiningRewardDistributed` once the reward is distributed successfully.
   * Emits the `MiningRewardDistributionFailed` once the contract fails to distribute reward.
   *
   * Note: This method should be called once in the end of each period.
   *
   */
  function _distributeMiningReward(address _consensusAddr, address payable _treasury) private {
    uint256 _amount = _miningReward[_consensusAddr];
    if (_amount > 0) {
      if (_sendRON(_treasury, _amount)) {
        emit MiningRewardDistributed(_consensusAddr, _treasury, _amount);
        return;
      }

      emit MiningRewardDistributionFailed(_consensusAddr, _treasury, _amount, address(this).balance);
    }
  }

  /**
   * @dev Distribute bonus of staking vesting for the bridge operator.
   *
   * Emits the `BridgeOperatorRewardDistributed` once the reward is distributed successfully.
   * Emits the `BridgeOperatorRewardDistributionFailed` once the contract fails to distribute reward.
   *
   * Note: This method should be called once in the end of each period.
   *
   */
  function _distributeBridgeOperatingReward(
    address _consensusAddr,
    address _bridgeOperator,
    address payable _treasury
  ) private {
    uint256 _amount = _bridgeOperatingReward[_consensusAddr];
    if (_amount > 0) {
      if (_sendRON(_treasury, _amount)) {
        emit BridgeOperatorRewardDistributed(_consensusAddr, _bridgeOperator, _treasury, _amount);
        return;
      }

      emit BridgeOperatorRewardDistributionFailed(
        _consensusAddr,
        _bridgeOperator,
        _treasury,
        _amount,
        address(this).balance
      );
    }
  }

  /**
   * @dev Helper function to settle rewards for delegators of `_currentValidators` at the end of each period,
   * then transfer the rewards from this contract to the staking contract, in order to finalize a period.
   *
   * Emits the `StakingRewardDistributed` once the reward is distributed successfully.
   * Emits the `StakingRewardDistributionFailed` once the contract fails to distribute reward.
   *
   * Note: This method should be called once in the end of each period.
   *
   */
  function _settleAndTransferDelegatingRewards(address[] memory _currentValidators, uint256 _totalDelegatingReward)
    private
  {
    IStaking _staking = _stakingContract;
    _staking.settleRewardPools(_currentValidators);

    if (_totalDelegatingReward > 0) {
      if (_sendRON(payable(address(_staking)), _totalDelegatingReward)) {
        emit StakingRewardDistributed(_totalDelegatingReward);
        return;
      }

      emit StakingRewardDistributionFailed(_totalDelegatingReward, address(this).balance);
    }
  }

  /**
   * @dev Updates the validator set based on the validator candidates from the Staking contract.
   *
   * Emits the `ValidatorSetUpdated` event.
   * Emits the `BridgeOperatorSetUpdated` event.
   *
   * Note: This method should be called once in the end of each period.
   *
   */
  function _syncValidatorSet(uint256 _newPeriod) private returns (address[] memory _newValidators) {
    uint256[] memory _balanceWeights;
    // This is a temporary approach since the slashing issue is still not finalized.
    // Read more about slashing issue at: https://www.notion.so/skymavis/Slashing-Issue-9610ae1452434faca1213ab2e1d7d944
    uint256 _minBalance = _stakingContract.minValidatorBalance();
    _balanceWeights = _filterUnsatisfiedCandidates(_minBalance);
    uint256[] memory _trustedWeights = _roninTrustedOrganizationContract.getConsensusWeights(_candidates);
    uint256 _newValidatorCount;
    (_newValidators, _newValidatorCount) = _pcPickValidatorSet(
      _candidates,
      _balanceWeights,
      _trustedWeights,
      _maxValidatorNumber,
      _maxPrioritizedValidatorNumber
    );
    _setNewValidatorSet(_newValidators, _newValidatorCount, _newPeriod);
    emit BridgeOperatorSetUpdated(_newPeriod, getBridgeOperators());
  }

  /**
   * @dev Private helper function helps writing the new validator set into the contract storage.
   *
   * Emits the `ValidatorSetUpdated` event.
   *
   * Note: This method should be called once in the end of each period.
   *
   */
  function _setNewValidatorSet(
    address[] memory _newValidators,
    uint256 _newValidatorCount,
    uint256 _newPeriod
  ) private {
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
    emit ValidatorSetUpdated(_newPeriod, _newValidators);
  }

  /**
   * @dev Activate/Deactivate the validators from producing blocks, based on their in jail status and maintenance status.
   *
   * Requirements:
   * - This method is called at the end of each epoch
   *
   * Emits the `BlockProducerSetUpdated` event.
   *
   */
  function _revampBlockProducers(uint256 _newPeriod, address[] memory _currentValidators) private {
    bool[] memory _maintainingList = _maintenanceContract.bulkMaintaining(_candidates, block.number + 1);

    for (uint _i = 0; _i < _currentValidators.length; _i++) {
      address _currentValidator = _currentValidators[_i];
      bool _isProducerBefore = isBlockProducer(_currentValidator);
      bool _isProducerAfter = !(_jailed(_currentValidator) || _maintainingList[_i]);

      if (!_isProducerBefore && _isProducerAfter) {
        _validatorMap[_currentValidator] = _validatorMap[_currentValidator].addFlag(
          EnumFlags.ValidatorFlag.BlockProducer
        );
        continue;
      }

      if (_isProducerBefore && !_isProducerAfter) {
        _validatorMap[_currentValidator] = _validatorMap[_currentValidator].removeFlag(
          EnumFlags.ValidatorFlag.BlockProducer
        );
      }
    }

    emit BlockProducerSetUpdated(_newPeriod, getBlockProducers());
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                             OTHER HELPER FUNCTIONS                                //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Returns whether the reward of the validator is put in jail (cannot join the set of validators) during the current period.
   */
  function _jailed(address _validatorAddr) internal view returns (bool) {
    return _jailedAtBlock(_validatorAddr, block.number);
  }

  /**
   * @dev Returns whether the reward of the validator is put in jail (cannot join the set of validators) at a specific block.
   */
  function _jailedAtBlock(address _validatorAddr, uint256 _blockNum) internal view returns (bool) {
    return _blockNum <= _jailedUntil[_validatorAddr];
  }

  /**
   * @dev Returns whether the block producer has no pending reward in that period.
   */
  function _miningRewardDeprecated(address _validatorAddr, uint256 _period) internal view returns (bool) {
    return _miningRewardDeprecatedAtPeriod[_validatorAddr][_period];
  }

  /**
   * @dev Returns whether the bridge operator has no pending reward in the period.
   */
  function _bridgeRewardDeprecated(address _validatorAddr, uint256 _period) internal view returns (bool) {
    return _bridgeRewardDeprecatedAtPeriod[_validatorAddr][_period];
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
   * @dev Returns whether the last period is ending when compared with the new period.
   */
  function _isPeriodEnding(uint256 _newPeriod) public view virtual returns (bool) {
    return _newPeriod > _lastUpdatedPeriod;
  }

  /**
   * @dev Returns the calculated period.
   */
  function _computePeriod(uint256 _timestamp) internal pure returns (uint256) {
    return _timestamp / 1 days;
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
