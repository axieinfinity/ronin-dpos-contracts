// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./interfaces/IStaking.sol";

contract Staking is IStaking, Initializable {
  mapping(address => uint256) claimableReward;
  mapping(address => uint256) pendingReward;

  /// @dev (consensusAddress => validator index) in `validators`
  mapping(address => uint256) public validatorIndexes;
  ValidatorInfo[] public validators;

  mapping(address => DelegatorInfo) delegators;

  /// @dev Configuration of maximum number of validator
  uint256 validatorThreshold;
  /// @dev Configuration of number of blocks that validator has to wait before unstaking, counted from staking time
  uint256 unstakingOnHoldBlocksNum;
  /// @dev Configuration of minimum balance for being a validator
  uint256 minValidatorBalance;

  event ProposedValidator(address indexed consensusAddr, address indexed stakingAddr, uint256 amount);
  event Staked(address indexed validator, uint256 amount);
  event Unstaked(address indexed validator, uint256 amount);
  event Delegated(address indexed delegator, address indexed validator, uint256 amount);
  event Undelegated(address indexed delegator, address indexed validator, uint256 amount);

  constructor() {
    _disableInitializers();
  }

  function initialize() external initializer {
    validatorThreshold = 50;
    unstakingOnHoldBlocksNum = 28800; // 28800 blocks ~= 1 day
    minValidatorBalance = 1e25; // 10M RON

    /// Add empty validator at 0-index
    validators.push();
  }

  ///
  /// VALIDATOR FUNCTIONS
  ///

  function proposeValidator(
    address _consensusAddr,
    address payable _feeAddr,
    uint256 _commissionRate,
    uint256 _amount
  ) external payable returns (uint256 index_) {
    require(validators.length < validatorThreshold, "Validators threshold exceeded");
    require(msg.value == _amount, "Transfer RON failed");
    require(!_existValidator(_consensusAddr), "Validator existed");

    (uint256 index, ValidatorInfo storage _currValidator) = _newValidator(_consensusAddr);

    _currValidator.consensusAddress = _consensusAddr;
    _currValidator.stakingAddress = msg.sender;
    _currValidator.feeAddress = _feeAddr;
    _currValidator.staked = _amount;
    _currValidator.balance = _amount;
    _currValidator.lastStakingBlock = block.number;

    emit ProposedValidator(_consensusAddr, msg.sender, _amount);

    return index;
  }

  function stake(address _consensusAddress, uint256 _amount) external payable {
    require(msg.value == _amount, "Transfer RON failed");

    ValidatorInfo storage currValidator = EnumerableMapValidatorInfo._getValidator(_consensusAddress);
    currValidator.staked += _amount;
    currValidator.stakedDiff += int256(_amount);
    currValidator.lastStakingBlock = block.number;

    emit Staked(_consensusAddress, _amount);
  }

  function unstake(address _consensusAddress, uint256 _amount) external {
    ValidatorInfo storage _currValidator = _getValidator(_consensusAddress);
    require(msg.sender == _currValidator.stakingAddress, "Caller must be the staker");
    require(block.number >= _currValidator.lastStakingBlock + unstakingOnHoldBlocksNum, "Staking is on hold period");

    uint256 remainingBalance = _currValidator.staked - _amount;
    require(remainingBalance >= minValidatorBalance || remainingBalance == 0, "Invalid unstaking amount");

    _currValidator.stakedDiff -= int256(_amount);
    _currValidator.balance = (_currValidator.staked == 0) ? 0 : _currValidator.balance - _amount;

    emit Unstaked(_currValidator.consensusAddress, _amount);
  }

  ///
  /// DELEGATOR FUNCTIONS
  ///

  function delegate(address _validatorAddr, uint256 _amount) external payable {
    require(msg.value == _amount, "Transfer RON failed");

    DelegatorInfo storage _currDelegator = delegators[msg.sender];
    _currDelegator.balance += _amount;
    _currDelegator.delegatedOfValidator[_validatorAddr] += _amount;

    ValidatorInfo storage _currValidator = _getValidator(_validatorAddr);
    _currValidator.stakedDiff += int256(_amount);

    emit Delegated(msg.sender, _validatorAddr, _amount);
  }

  function undelegate(address _validatorAddr, uint256 _amount) external payable {
    DelegatorInfo storage _currDelegator = delegators[msg.sender];
    require (_currDelegator.delegatedOfValidator[_validatorAddr] >= _amount, "Invalid undelegating amount");

    _currDelegator.balance -= _amount;
    _currDelegator.delegatedOfValidator[_validatorAddr] -= _amount;

    ValidatorInfo storage _currValidator = _getValidator(_validatorAddr);
    _currValidator.stakedDiff -= int256(_amount);

    emit Undelegated(msg.sender, _validatorAddr, _amount);
  }

  ///
  /// HELPER ON VALIDATOR MAPPING FUNCTIONS
  ///

  function _existValidator(address _consensusAddr) private view returns (bool) {
    uint256 _index = validatorIndexes[_consensusAddr];
    return (_index != 0);
  }

  function _getValidator(address _consensusAddr) private view returns (ValidatorInfo storage) {
    (bool success, ValidatorInfo storage currValidator) = _tryGetValidator(_consensusAddr);
    require(success, "Nonexistent validator");
    return currValidator;
  }

  function _tryGetValidator(address _consensusAddr) private view returns (bool, ValidatorInfo storage) {
    uint256 _index = validatorIndexes[_consensusAddr];
    ValidatorInfo storage _currValidator = validators[_index];

    if (_index == 0) return (false, _currValidator);

    return (true, _currValidator);
  }

  function _newValidator(address _consensusAddr) private returns (uint256, ValidatorInfo storage) {
    uint256 index = validators.length;
    validatorIndexes[_consensusAddr] = index;
    return (index, validators.push());
  }

}
