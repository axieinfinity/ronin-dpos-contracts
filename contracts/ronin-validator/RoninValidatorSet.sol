// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "../interfaces/ISlashIndicator.sol";
import "../interfaces/IStaking.sol";
import "../interfaces/IRoninValidatorSet.sol";
import "../libraries/Sorting.sol";
import "../libraries/Math.sol";

contract RoninValidatorSet is IRoninValidatorSet, Initializable {
  /// @dev Governance admin address.
  address internal _governanceAdmin; // TODO(Thor): add setter.
  /// @dev Slash indicator contract address.
  address internal _slashIndicatorContract; // Change type to address for testing purpose
  /// @dev Staking contract address.
  address internal _stakingContract; // Change type to address for testing purpose

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
  /// @dev Mapping from epoch index => flag indicating the epoch is wrapped up or not
  mapping(uint256 => bool) internal _wrappedUp;

  /// @dev Mapping from validator address => the last **period** that the validator has no pending reward
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

  modifier whenEpochEnding() {
    require(epochEndingAt(block.number), "RoninValidatorSet: only allowed at the end of epoch");
    _;
  }

  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract storage.
   */
  function initialize(
    address __governanceAdmin,
    address __slashIndicatorContract,
    address __stakingContract,
    uint256 __maxValidatorNumber,
    uint256 __numberOfBlocksInEpoch,
    uint256 __numberOfEpochsInPeriod
  ) external initializer {
    _governanceAdmin = __governanceAdmin;
    _slashIndicatorContract = __slashIndicatorContract;
    _stakingContract = __stakingContract;
    _maxValidatorNumber = __maxValidatorNumber;
    _numberOfBlocksInEpoch = __numberOfBlocksInEpoch;
    _numberOfEpochsInPeriod = __numberOfEpochsInPeriod;
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                              FUNCTIONS FOR COINBASE                               //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function submitBlockReward() external payable override onlyCoinbase {
    uint256 _reward = msg.value;
    if (_reward == 0) {
      return;
    }

    address _coinbaseAddr = msg.sender;
    // Deprecates reward for non-validator or slashed validator
    if (
      !_isValidator(_coinbaseAddr) || _jailed(_coinbaseAddr) || _rewardDeprecated(_coinbaseAddr, periodOf(block.number))
    ) {
      emit RewardDeprecated(_coinbaseAddr, _reward);
      return;
    }

    emit BlockRewardSubmitted(_coinbaseAddr, _reward);
    IStaking _staking = IStaking(_stakingContract);
    uint256 _rate = _staking.commissionRateOf(_coinbaseAddr);
    uint256 _miningAmount = (_rate * _reward) / 100_00;
    uint256 _delegatingAmount = _reward - _miningAmount;

    _miningReward[_coinbaseAddr] += _miningAmount;
    _delegatingReward[_coinbaseAddr] += _delegatingAmount;
    _staking.recordReward(_coinbaseAddr, _delegatingAmount);
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function wrapUpEpoch() external payable override onlyCoinbase whenEpochEnding {
    uint256 _epoch = epochOf(block.number);
    require(_wrappedUp[_epoch] == false, "RoninValidatorSet: query for already wrapped up epoch");
    _wrappedUp[_epoch] = true;

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
          address _treasury = _staking.treasuryAddressOf(_validatorAddr);
          (bool _success, ) = _treasury.call{ value: _miningAmount }("");
          require(_success, "RoninValidatorSet: could not transfer RON treasury addr");
        }
      }

      _delegatingAmount += _delegatingReward[_validatorAddr];
      delete _delegatingReward[_validatorAddr];
      // TODO: emit events
    }

    if (_periodEnding) {
      ISlashIndicator(_slashIndicatorContract).resetCounters(_validators);
    }

    _staking.settleRewardPools(_validators);
    if (_delegatingAmount > 0) {
      (bool _success, ) = address(_staking).call{ value: _delegatingAmount }("");
      require(_success, "RoninValidatorSet: could not transfer RON to staking contract");
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
   * @dev Updates the validator set based on the validator candidates from the Staking contract.
   */
  function _updateValidatorSet() internal {
    (address[] memory _candidates, uint256[] memory _weights) = IStaking(_stakingContract).getCandidateWeights();
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
    uint256 _newValidatorCount = Math.min(_maxValidatorNumber, _candidates.length);

    // TODO: pick at least M governers as validators

    for (uint256 _i = _newValidatorCount; _i < validatorCount; _i++) {
      delete _validator[_i];
      delete _validatorMap[_validator[_i]];
    }

    for (uint256 _i = 0; _i < _newValidatorCount; _i++) {
      delete _validatorMap[_validator[_i]];

      address _newValidator = _candidates[_i];
      _validatorMap[_newValidator] = true;
      _validator[_i] = _newValidator;
    }

    validatorCount = _newValidatorCount;
    _lastUpdatedBlock = block.number;
    // TODO(Thor): emit validator set updated.
  }
}
