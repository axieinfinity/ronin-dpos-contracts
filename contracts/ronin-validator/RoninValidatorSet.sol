// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "../interfaces/ISlashIndicator.sol";
import "../interfaces/IStaking.sol";
import "../interfaces/IRoninValidatorSet.sol";
import "../libraries/Sorting.sol";
import "../libraries/Math.sol";

contract RoninValidatorSet is IRoninValidatorSet {
  /// @dev Governance admin contract address.
  address internal _governanceAdminContract; // TODO(Thor): add setter.
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

  /// @dev Returns the number of epochs in a period
  uint256 internal _numberOfBlocksInEpoch;
  /// @dev The number of blocks in a epoch
  uint256 internal _numberOfEpochsInPeriod;
  /// @dev The last updated block
  uint256 internal _lastUpdatedBlock;

  /// @dev Mapping from period index => validator address => flag indicating whether the validator has no pending reward in that period
  mapping(uint256 => mapping(address => bool)) internal _noPendingReward;
  /// @dev Mapping from validator address => the last block that the validator is jailed
  mapping(address => uint256) internal _jailedUntil;
  /// @dev Mapping from validator address => pending reward from producing block
  mapping(address => uint256) internal _miningReward;
  /// @dev Mapping from validator address => pending reward from delegating
  mapping(address => uint256) internal _delegatingReward;

  /// @dev The amount of RON to slash felony.
  uint256 public slashFelonyAmount;
  /// @dev The amount of RON to slash double sign.
  uint256 public slashDoubleSignAmount;

  modifier onlyCoinbase() {
    require(msg.sender == block.coinbase, "RoninValidatorSet: method caller is not coinbase");
    _;
  }

  modifier whenEndEpoch() {
    require(epochEnded(block.number), "RoninValidatorSet: only allowed at the end of epoch");
    _;
  }

  constructor() {}

  ///////////////////////////////////////////////////////////////////////////////////////
  //                              FUNCTIONS FOR COINBASE                               //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function submitBlockReward() external payable override onlyCoinbase {
    uint256 _reward = msg.value;
    address _validatorAddr = msg.sender;
    if (!_isValidator(_validatorAddr)) {
      // TODO(Thor): emit the deprecated reward event
      return;
    }

    if (_jailed(_validatorAddr) || _noPendingReward[periodOf(block.number)][_validatorAddr]) {
      // TODO(Thor): emit the deprecated reward event
      return;
    }

    IStaking _staking = IStaking(_stakingContract);
    uint256 _rate = _staking.commissionRateOf(_validatorAddr);
    uint256 _miningAmount = (_rate * _reward) / 100_00;
    uint256 _delegatingAmount = _reward - _miningAmount;

    _miningReward[_validatorAddr] += _miningAmount;
    _delegatingReward[_validatorAddr] += _delegatingAmount;
    IStaking(_stakingContract).recordRewardForDelegators(_validatorAddr, _delegatingAmount);
    // TODO(Thor): emit event
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function wrapUpEpoch() external payable override onlyCoinbase whenEndEpoch {
    if (periodEnded(block.number)) {
      IStaking _staking = IStaking(_stakingContract);
      ISlashIndicator _slashIndicator = ISlashIndicator(_slashIndicatorContract);

      address _validatorAddr;
      uint256 _miningAmount;
      uint256 _delegatingAmount;
      for (uint _i = 0; _i < validatorCount; _i++) {
        _validatorAddr = _validator[_i];
        _slashIndicator.resetCounter(_validatorAddr);
        _miningAmount = _miningReward[_validatorAddr];
        _delegatingAmount = _delegatingReward[_validatorAddr];
        if (!_jailed(_validatorAddr) && !_noPendingReward[periodOf(block.number)][_validatorAddr]) {
          // TODO(Thor): use `call` to transfer reward with reentrancy gruard
          require(
            payable(_staking.treasuryAddressOf(_validatorAddr)).send(_miningAmount),
            "RoninValidatorSet: could not transfer RON"
          );
          require(payable(address(_staking)).send(_delegatingAmount), "RoninValidatorSet: could not transfer RON");

          _staking.settleRewardPoolForDelegators(_validatorAddr);
        }
        _miningReward[_validatorAddr] = 0;
        _delegatingReward[_validatorAddr] = 0;
        // TODO: emit event
      }
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
  function governanceAdminContract() external view override returns (address) {
    return _governanceAdminContract;
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
  function slashMisdemeanor(address _validatorAddr) public override {
    _noPendingReward[periodOf(block.number)][_validatorAddr] = true;
    _miningReward[_validatorAddr] = 0;
    _delegatingReward[_validatorAddr] = 0;
    IStaking(_stakingContract).sinkPendingReward(_validatorAddr);
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function slashFelony(address _validatorAddr) external override {
    slashMisdemeanor(_validatorAddr);
    IStaking(_stakingContract).deductStakingAmount(_validatorAddr, slashFelonyAmount);
    uint256 _jailedBlock = block.number + 2 * 28800; // TODO: make this constant number to variable
    _jailedUntil[_validatorAddr] = Math.max(_jailedUntil[_validatorAddr], _jailedBlock);
    // TODO(Thor): emit event
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function slashDoubleSign(address _validatorAddr) external override {
    slashMisdemeanor(_validatorAddr);
    IStaking(_stakingContract).deductStakingAmount(_validatorAddr, slashDoubleSignAmount);
    _jailedUntil[_validatorAddr] = type(uint256).max;
    // TODO(Thor): emit event
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
  function noPendingReward(address[] memory _addrList, uint256 _period)
    external
    view
    override
    returns (bool[] memory _result)
  {
    for (uint256 _i; _i < _addrList.length; _i++) {
      _result[_i] = _noPendingReward[_period][_addrList[_i]];
    }
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                             FUNCTIONS FOR NORMAL USER                             //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function epochOf(uint256 _block) public view override returns (uint256) {
    return _block / _numberOfBlocksInEpoch + 1;
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function periodOf(uint256 _block) public view override returns (uint256) {
    return _block / (_numberOfBlocksInEpoch * _numberOfEpochsInPeriod) + 1;
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function getValidators() external view override returns (address[] memory _validatorList) {
    _validatorList = new address[](validatorCount);
    for (uint _i = 0; _i < _validatorList.length; _i++) {
      _validatorList[_i] = _validator[_i];
    }
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function epochEnded(uint256 _block) public view returns (bool) {
    return _block % _numberOfBlocksInEpoch == _numberOfBlocksInEpoch - 1;
  }

  /**
   * @inheritdoc IRoninValidatorSet
   */
  function periodEnded(uint256 _block) public view returns (bool) {
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
