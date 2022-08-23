// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./interfaces/IStaking.sol";

abstract contract Staking is IStaking, Initializable {
  /// TODO: expose fn to get validator info by validator address.
  /// @dev Mapping from consensus address => validator index in `validatorCandidates`.
  mapping(address => uint256) internal _validatorIndexes;
  /// TODO: expose fn returns the whole validator arry.
  /// @dev Validator array.
  ValidatorCandidate[] public validatorCandidates;

  /// @dev Mapping from delegator address => consensus address => delegated amount.
  mapping(address => mapping(address => uint256)) delegatedAmount;

  // TODO: expose this fn in the interface
  /// @dev Configuration of maximum number of validator
  uint256 public totalValidatorThreshold;

  // TODO: expose this fn in the interface
  /// @dev Configuration of number of blocks that validator has to wait before unstaking, counted from staking time
  uint256 public unstakingOnHoldBlocksNum;

  // TODO: expose this fn in the interface
  /// @dev Configuration of minimum balance for being a validator
  uint256 public minValidatorBalance;

  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract storage.
   */
  function initialize() external initializer {
    /// TODO: bring this constant variable to params.
    totalValidatorThreshold = 50;
    unstakingOnHoldBlocksNum = 28800; // 28800 blocks ~= 1 day
    minValidatorBalance = 3 * 1e6 * 1e18; // 3m RON
    /// Add empty validator at 0-index
    validatorCandidates.push();
  }

  /**
   * @dev See {IStaking-proposeValidator}.
   */
  function proposeValidator(
    address _consensusAddr,
    address payable _treasuryAddr,
    uint256 _commissionRate
  ) external payable returns (uint256 _candidateIdx) {
    uint256 _amount = msg.value;
    address _stakingAddr = msg.sender;

    require(validatorCandidates.length < totalValidatorThreshold, "Staking: query for exceeded validator array length");
    require(_validatorIndexes[_consensusAddr] == 0, "Staking: query for existed candidate");
    require(_amount > minValidatorBalance, "Staking: insuficient amount");
    require(_treasuryAddr.send(0), "Staking: invalid treasury address");

    _candidateIdx = validatorCandidates.length;
    ValidatorCandidate storage _candidate = validatorCandidates.push();
    _candidate.consensusAddr = _consensusAddr;
    _candidate.stakingAddr = _stakingAddr;
    _candidate.treasuryAddr = _treasuryAddr;
    _candidate.commissionRate = _commissionRate;
    _candidate.stakedAmount = _amount;

    emit ValidatorProposed(_consensusAddr, _stakingAddr, _amount, _candidate);
  }

  /**
   * @dev See {IStaking-stake}.
   */
  function stake(address _consensusAddr) external payable {
    uint256 _amount = msg.value;
    ValidatorCandidate storage _candidate = _getCandidate(_consensusAddr);
    require(_candidate.stakingAddr == msg.sender, "Staking: invalid staking address");

    _candidate.stakedAmount += _amount;
    emit Staked(_consensusAddr, _amount);
  }

  /**
   * @dev See {IStaking-unstake}.
   */
  function unstake(address _consensusAddr, uint256 _amount) external {
    ValidatorCandidate storage _candidate = _getCandidate(_consensusAddr);
    require(_candidate.stakingAddr == msg.sender, "Staking: invalid staking address");
    require(_amount < _candidate.stakedAmount, "Staking: insufficient staked amount");

    uint256 remainAmount = _candidate.stakedAmount - _amount;
    require(remainAmount >= minValidatorBalance, "Staking: invalid staked amount left");

    _candidate.stakedAmount = _amount;
    emit Unstaked(_consensusAddr, _amount);
  }

  /**
   * @dev See {IStaking-delegate}.
   */
  function delegate(address _consensusAddr) public payable {
    _delegate(msg.sender, _consensusAddr, msg.value);
  }

  /**
   * @dev See {IStaking-delegate}.
   */
  function undelegate(address _consensusAddr, uint256 _amount) public {
    _undelegate(msg.sender, _consensusAddr, _amount);
    require(payable(msg.sender).send(_amount), "Staking: could not transfer RON");
  }

  /**
   * @dev TODO: move to IStaking.sol
   */
  function redelegate(
    address _consensusAddrSrc,
    address _consensusAddrDst,
    uint256 _amount
  ) external {
    _undelegate(msg.sender, _consensusAddrSrc, _amount);
    _delegate(msg.sender, _consensusAddrDst, _amount);
  }

  /**
   * @dev TODO
   */
  function getRewards(address[] calldata _consensusAddrList)
    external
    view
    returns (uint256[] memory _pending, uint256[] memory _claimable)
  {
    revert("Unimplemented");
  }

  /**
   * @dev Claims rewards.
   */
  function claimRewards(address[] calldata _consensusAddrList, uint256 _amounts) external returns (uint256 _amount) {
    revert("Unimplemented");
  }

  /**
   * @dev Claims all pending rewards and delegates them to the consensus address.
   */
  function delegateRewards(address[] calldata _consensusAddrList, address _consensusAddrDst)
    external
    returns (uint256 _amount)
  {
    revert("Unimplemented");
  }

  /**
   * @dev Delegates from a validator address.
   *
   * Requirements:
   * - The validator is an existed candidate.
   *
   * Emits the `Delegated` event.
   *
   * @notice This function does not verify the `msg.value` with the amount.
   */
  function _delegate(
    address _delegator,
    address _consensusAddr,
    uint256 _amount
  ) internal {
    ValidatorCandidate storage _candidate = _getCandidate(_consensusAddr);
    _candidate.delegatedAmount += _amount;
    delegatedAmount[_delegator][_consensusAddr] += _amount;

    emit Delegated(_delegator, _consensusAddr, _amount);
  }

  /**
   * @dev Undelegates from a validator address.
   *
   * Requirements:
   * - The validator is an existed candidate.
   * - The delegated amount is larger than or equal to the undelegated amount.
   *
   * Emits the `Undelegated` event.
   *
   * @notice Consider transferring back the amount of RON after calling this function.
   */
  function _undelegate(
    address _delegator,
    address _consensusAddr,
    uint256 _amount
  ) internal {
    require(delegatedAmount[_delegator][_consensusAddr] >= _amount, "Staking: insufficient amount to undelegate");

    ValidatorCandidate storage _candidate = _getCandidate(_consensusAddr);
    _candidate.delegatedAmount -= _amount;
    delegatedAmount[_delegator][_consensusAddr] -= _amount;

    emit Undelegated(_delegator, _consensusAddr, _amount);
  }

  /**
   * @dev Returns the validator candidate in form storage.
   *
   * Requirements:
   * - The candidate is already existed.
   *
   */
  function _getCandidate(address _consensusAddr) internal view returns (ValidatorCandidate storage _candidate) {
    uint256 _idx = _validatorIndexes[_consensusAddr];
    require(_idx > 0, "Staking: query for nonexistent candidate");
    _candidate = validatorCandidates[_idx];
  }
}
