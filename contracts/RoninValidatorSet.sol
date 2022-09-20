// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "./extensions/RONTransferHelper.sol";
import "./interfaces/ISlashIndicator.sol";
import "./interfaces/IStaking.sol";
import "./interfaces/IStakingVesting.sol";
import "./interfaces/IRoninValidatorSet.sol";
import "./libraries/Sorting.sol";
import "./libraries/Math.sol";

contract RoninValidatorSet is IRoninValidatorSet, RONTransferHelper, Initializable {
  /// @dev Governance admin address.
  address internal _governanceAdmin;
  /// @dev Slash indicator contract address.
  address internal _slashIndicatorContract; // Change type to address for testing purpose
  /// @dev Staking contract address.
  address internal _stakingContract; // Change type to address for testing purpose
  /// @dev Staking vesting contract address.
  address internal _stakingVestingContract;

  /// @dev The total of validators
  uint256 public validatorCount;
  /// @dev Mapping from validator index => validator address
  mapping(uint256 => address) internal _validator;
  /// @dev Mapping from validator address => bool
  mapping(address => bool) internal _validatorMap;
  /// @dev The maximum number of validator.
  uint256 internal _maxValidatorNumber;

  /// @dev The number of blocks in a epoch
  uint256 internal _numberOfBlocksInEpoch;
  /// @dev Returns the number of epochs in a period
  uint256 internal _numberOfEpochsInPeriod;
  /// @dev The last updated block
  uint256 internal _lastUpdatedBlock;

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

  modifier onlySlashIndicatorContract() {
    require(msg.sender == _slashIndicatorContract, "RoninValidatorSet: method caller must be slash indicator contract");
    _;
  }

  modifier onlyGovernanceAdmin() {
    require(msg.sender == _governanceAdmin, "RoninValidatorSet: method caller must be governance admin");
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
    address __governanceAdmin,
    address __slashIndicatorContract,
    address __stakingContract,
    address __stakingVestingContract,
    uint256 __maxValidatorNumber,
    uint256 __numberOfBlocksInEpoch,
    uint256 __numberOfEpochsInPeriod
  ) external initializer {
    _setGovernanceAdmin(__governanceAdmin);

    _slashIndicatorContract = __slashIndicatorContract;
    _stakingContract = __stakingContract;
    _stakingVestingContract = __stakingVestingContract;

    _setMaxValidatorNumber(__maxValidatorNumber);
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
      !_isValidator(_coinbaseAddr) || _jailed(_coinbaseAddr) || _rewardDeprecated(_coinbaseAddr, periodOf(block.number))
    ) {
      emit RewardDeprecated(_coinbaseAddr, _submittedReward);
      return;
    }

    uint256 _bonusReward = IStakingVesting(_stakingVestingContract).requestBlockBonus();
    uint256 _reward = _submittedReward + _bonusReward;

    IStaking _staking = IStaking(_stakingContract);
    uint256 _rate = _staking.commissionRateOf(_coinbaseAddr);
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
          address payable _treasury = payable(_staking.treasuryAddressOf(_validatorAddr));
          require(_sendRON(_treasury, _miningAmount), "RoninValidatorSet: could not transfer RON treasury address");
          emit MiningRewardDistributed(_validatorAddr, _miningAmount);
        }
      }

      _delegatingAmount += _delegatingReward[_validatorAddr];
      delete _delegatingReward[_validatorAddr];
    }

    if (_periodEnding) {
      // TODO: reset for candidates / kicked validators
      ISlashIndicator(_slashIndicatorContract).resetCounters(_validators);
    }

    _staking.settleRewardPools(_validators);
    if (_delegatingAmount > 0) {
      require(_sendRON(payable(address(_staking)), 0), "RoninValidatorSet: could not transfer RON to staking contract");
      emit StakingRewardDistributed(_delegatingAmount);
    }

    _updateValidatorSet();
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
  function governanceAdmin() external view override returns (address) {
    return _governanceAdmin;
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function slashIndicatorContract() external view override returns (address) {
    return _slashIndicatorContract;
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function stakingContract() external view override returns (address) {
    return _stakingContract;
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function stakingVestingContract() external view override returns (address) {
    return _stakingVestingContract;
  }

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
      IStaking(_stakingContract).deductStakingAmount(_validatorAddr, _slashAmount);
    }

    emit ValidatorSlashed(_validatorAddr, _jailedUntil[_validatorAddr], _slashAmount);
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
    return _block / _numberOfBlocksInEpoch + 1;
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function periodOf(uint256 _block) public view virtual override returns (uint256) {
    return _block / (_numberOfBlocksInEpoch * _numberOfEpochsInPeriod) + 1;
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
   * @inheritdoc IRoninValidatorSet
   */
  function numberOfEpochsInPeriod() external view override returns (uint256 _numberOfEpochs) {
    return _numberOfEpochsInPeriod;
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function numberOfBlocksInEpoch() external view override returns (uint256 _numberOfBlocks) {
    return _numberOfBlocksInEpoch;
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function maxValidatorNumber() external view override returns (uint256 _maximumValidatorNumber) {
    return _maxValidatorNumber;
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                         FUNCTIONS FOR GOVERNANCE ADMIN                            //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function setGovernanceAdmin(address __governanceAdmin) external override onlyGovernanceAdmin {
    _setGovernanceAdmin(__governanceAdmin);
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function setMaxValidatorNumber(uint256 __maxValidatorNumber) external override onlyGovernanceAdmin {
    _setMaxValidatorNumber(__maxValidatorNumber);
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function setNumberOfBlocksInEpoch(uint256 __numberOfBlocksInEpoch) external override onlyGovernanceAdmin {
    _setNumberOfBlocksInEpoch(__numberOfBlocksInEpoch);
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function setNumberOfEpochsInPeriod(uint256 __numberOfEpochsInPeriod) external override onlyGovernanceAdmin {
    _setNumberOfEpochsInPeriod(__numberOfEpochsInPeriod);
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                                  HELPER FUNCTIONS                                 //
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
   * @dev Returns whether the address `_addr` is validator or not.
   */
  function _isValidator(address _addr) internal view returns (bool) {
    return _validatorMap[_addr];
  }

  /**
   * @dev Returns validator candidates list.
   */
  function _getValidatorCandidates() internal view returns (address[] memory _candidates) {
    uint256[] memory _weights;
    (_candidates, _weights) = IStaking(_stakingContract).getCandidateWeights();
    // TODO: filter validators that do not have enough min balance
    uint256 _newLength = _candidates.length;
    for (uint256 _i; _i < _candidates.length; _i++) {
      if (_jailed(_candidates[_i])) {
        _newLength--;
        _candidates[_i] = _candidates[_newLength];
        _weights[_i] = _weights[_newLength];
      }
    }

    assembly {
      mstore(_candidates, _newLength)
      mstore(_weights, _newLength)
    }

    _candidates = Sorting.sort(_candidates, _weights);
    // TODO: pick at least M governers as validators
  }

  /**
   * @dev Updates the validator set based on the validator candidates from the Staking contract.
   *
   * Emits the `ValidatorSetUpdated` event.
   *
   */
  function _updateValidatorSet() internal virtual {
    address[] memory _candidates = _getValidatorCandidates();

    uint256 _newValidatorCount = Math.min(_maxValidatorNumber, _candidates.length);

    assembly {
      mstore(_candidates, _newValidatorCount)
    }

    for (uint256 _i = _newValidatorCount; _i < validatorCount; _i++) {
      delete _validator[_i];
      delete _validatorMap[_validator[_i]];
    }

    for (uint256 _i = 0; _i < _newValidatorCount; _i++) {
      address _newValidator = _candidates[_i];
      if (_newValidator == _validator[_i]) {
        continue;
      }
      delete _validatorMap[_validator[_i]];
      _validatorMap[_newValidator] = true;
      _validator[_i] = _newValidator;
    }

    validatorCount = _newValidatorCount;
    emit ValidatorSetUpdated(_candidates);
  }

  /**
   * @dev Updates the address of governance admin
   */
  function _setGovernanceAdmin(address __governanceAdmin) internal {
    if (__governanceAdmin == _governanceAdmin) {
      return;
    }

    require(__governanceAdmin != address(0), "RoninValidatorSet: Cannot set admin to zero address");

    _governanceAdmin = __governanceAdmin;
    emit GovernanceAdminUpdated(__governanceAdmin);
  }

  /**
   * @dev Updates the max validator number
   */
  function _setMaxValidatorNumber(uint256 __maxValidatorNumber) internal {
    _maxValidatorNumber = __maxValidatorNumber;
    emit MaxValidatorNumberUpdated(__maxValidatorNumber);
  }

  /**
   * @dev Updates the number of blocks in epoch
   */
  function _setNumberOfBlocksInEpoch(uint256 __numberOfBlocksInEpoch) internal {
    _numberOfBlocksInEpoch = __numberOfBlocksInEpoch;
    emit NumberOfBlocksInEpochUpdated(__numberOfBlocksInEpoch);
  }

  /**
   * @dev Updates the number of epochs in period
   */
  function _setNumberOfEpochsInPeriod(uint256 __numberOfEpochsInPeriod) internal {
    _numberOfEpochsInPeriod = __numberOfEpochsInPeriod;
    emit NumberOfEpochsInPeriodUpdated(__numberOfEpochsInPeriod);
  }

  /**
   * @dev Only receives RON from staking vesting contract.
   */
  function _fallback() internal view {
    require(
      msg.sender == _stakingVestingContract,
      "RoninValidatorSet: only receives RON from staking vesting contract"
    );
  }
}
