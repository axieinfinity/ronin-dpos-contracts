// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../interfaces/IStaking.sol";
import "./RewardCalculation.sol";

abstract contract StakingManager is IStaking, RewardCalculation {
  /// @dev Mapping from  pool address => delegator address => delegated amount.
  mapping(address => mapping(address => uint256)) internal _delegatedAmount;

  modifier noEmptyValue() {
    require(msg.value > 0, "StakingManager: query with empty value");
    _;
  }

  modifier notCandidateAdmin(address _consensusAddr) {
    ValidatorCandidate memory _candidate = _getCandidate(_consensusAddr);
    require(msg.sender != _candidate.candidateAdmin, "StakingManager: method caller must not be the candidate admin");
    _;
  }

  /**
   * @inheritdoc IRewardPool
   */
  function balanceOf(address _poolAddr, address _user)
    public
    view
    override(IRewardPool, RewardCalculation)
    returns (uint256)
  {
    return _delegatedAmount[_poolAddr][_user];
  }

  /**
   * @inheritdoc IRewardPool
   */
  function totalBalance(address _poolAddr) public view override(IRewardPool, RewardCalculation) returns (uint256) {
    ValidatorCandidate storage _candidate = _getCandidate(_poolAddr);
    return _candidate.delegatedAmount;
  }

  /**
   * @inheritdoc IStaking
   */
  function minValidatorBalance() public view virtual returns (uint256);

  /**
   * @inheritdoc IStaking
   */
  function maxValidatorCandidate() public view virtual returns (uint256);

  /**
   * @dev IStaking
   */
  function getValidatorCandidateLength() public view virtual returns (uint256);

  ///////////////////////////////////////////////////////////////////////////////////////
  //                          FUNCTIONS FOR VALIDATOR CANDIDATE                        //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc IStaking
   */
  function proposeValidator(
    address _consensusAddr,
    address payable _treasuryAddr,
    uint256 _commissionRate
  ) external payable override returns (uint256 _candidateIdx) {
    uint256 _amount = msg.value;
    address _stakingAddr = msg.sender;
    _candidateIdx = _proposeValidator(_consensusAddr, _treasuryAddr, _commissionRate, _amount, _stakingAddr);
    _stake(_consensusAddr, _stakingAddr, _amount);
  }

  /**
   * @inheritdoc IStaking
   */
  function stake(address _consensusAddr) external payable override noEmptyValue {
    _stake(_consensusAddr, msg.sender, msg.value);
  }

  /**
   * @inheritdoc IStaking
   */
  function unstake(address _consensusAddr, uint256 _amount) external override {
    address _delegator = msg.sender;

    ValidatorCandidate storage _candidate = _getCandidate(_consensusAddr);

    uint256 remainAmount = _candidate.stakedAmount - _amount;
    require(remainAmount >= minValidatorBalance(), "StakingManager: invalid staked amount left");

    _unstake(_candidate, _delegator, _amount);

    // TODO(Thor): replace by `call` and use reentrancy gruard
    require(payable(msg.sender).send(_amount), "StakingManager: could not transfer RON");
  }

  /**
   * @inheritdoc IStaking
   */
  function renounce(
    address /* _consensusAddr */
  ) external {
    // TODO(Thor): implement this function
    revert("unimplemented");
  }

  /**
   * @dev Proposes a candidate to become a valdiator.
   *
   * Requirements:
   * -
   * - The validator length is not exceeded the total validator threshold `_maxValidatorCandidate`.
   * - The amount is larger than or equal to the minimum validator balance `_minValidatorBalance`.
   *
   * Emits the `ValidatorProposed` event.
   *
   * @return _candidateIdx The bitwise negative of candidate index.
   *
   */
  function _proposeValidator(
    address _consensusAddr,
    address payable _treasuryAddr,
    uint256 _commissionRate,
    uint256 _amount,
    address _candidateAdmin
  ) internal returns (uint256 _candidateIdx) {
    uint256 _length = getValidatorCandidateLength();
    require(_length < maxValidatorCandidate(), "StakingManager: exceeds maximum number of candidates");
    require(_getCandidateIndex(_consensusAddr) == 0, "StakingManager: query for existed candidate");
    require(_amount >= minValidatorBalance(), "StakingManager: insufficient amount");
    // TODO(Thor): replace by `call` and use reentrancy gruard
    require(_treasuryAddr.send(0), "StakingManager: invalid treasury address");

    _candidateIdx = ~_length;
    _setCandidateIndex(_consensusAddr, _candidateIdx);
    _createValidatorCandidate(_consensusAddr, _candidateAdmin, _treasuryAddr, _commissionRate);

    emit ValidatorProposed(_consensusAddr, _candidateAdmin, _length);
  }

  /**
   * @dev Stakes for the validator candidate.
   *
   * Requirements:
   * - The user address is equal the candidate staking address.
   *
   * Emits the `Staked` event.
   *
   */
  function _stake(
    address _poolAddr,
    address _user,
    uint256 _amount
  ) internal {
    ValidatorCandidate storage _candidate = _getCandidate(_poolAddr);
    require(_candidate.candidateAdmin == _user, "StakingManager: user is not the candidate admin");

    _candidate.stakedAmount += _amount;
    emit Staked(_poolAddr, _amount);

    _delegate(_poolAddr, _user, _amount);
  }

  /**
   * @dev Withdraws the staked amount `_amount` for the validator candidate.
   *
   * Requirements:
   * - The remain balance must be greater than the minimum validator candidate thresold `minValidatorBalance()`.
   *
   * Emits the `Unstaked` event.
   *
   */
  function _unstake(
    ValidatorCandidate storage _candidate,
    address _user,
    uint256 _amount
  ) internal {
    require(_candidate.candidateAdmin == _user, "StakingManager: user is not the candidate admin");
    require(_amount <= _candidate.stakedAmount, "StakingManager: insufficient staked amount");

    _candidate.stakedAmount -= _amount;
    emit Unstaked(_candidate.consensusAddr, _amount);
    _undelegate(_candidate.consensusAddr, _user, _amount);
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                             FUNCTIONS FOR DELEGATOR                               //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc IStaking
   */
  function delegate(address _consensusAddr) external payable noEmptyValue notCandidateAdmin(_consensusAddr) {
    _delegate(_consensusAddr, msg.sender, msg.value);
  }

  /**
   * @inheritdoc IStaking
   */
  function undelegate(address _consensusAddr, uint256 _amount) external notCandidateAdmin(_consensusAddr) {
    address payable _delegator = payable(msg.sender);
    _undelegate(_consensusAddr, _delegator, _amount);
    // TODO(Thor): replace by `call` and use reentrancy gruard
    require(_delegator.send(_amount), "StakingManager: could not transfer RON");
  }

  /**
   * @inheritdoc IStaking
   */
  function redelegate(
    address _consensusAddrSrc,
    address _consensusAddrDst,
    uint256 _amount
  ) external notCandidateAdmin(_consensusAddrDst) {
    address _delegator = msg.sender;
    _undelegate(_consensusAddrSrc, _delegator, _amount);
    _delegate(_consensusAddrDst, _delegator, _amount);
  }

  /**
   * @inheritdoc IStaking
   */
  function getRewards(address _user, address[] calldata _poolAddrList)
    external
    view
    returns (uint256[] memory _pendings, uint256[] memory _claimables)
  {
    address _consensusAddr;
    for (uint256 _i = 0; _i < _poolAddrList.length; _i++) {
      _consensusAddr = _poolAddrList[_i];

      uint256 _totalReward = getTotalReward(_consensusAddr, _user);
      uint256 _claimableReward = getClaimableReward(_consensusAddr, _user);
      _pendings[_i] = _totalReward - _claimableReward;
      _claimables[_i] = _claimableReward;
    }
  }

  /**
   * @inheritdoc IStaking
   */
  function claimRewards(address[] calldata _consensusAddrList) external returns (uint256 _amount) {
    _amount = _claimRewards(msg.sender, _consensusAddrList);
    // TODO(Thor): replace by `call` and use reentrancy gruard
    require(payable(msg.sender).send(_amount), "StakingManager: could not transfer RON");
  }

  /**
   * @inheritdoc IStaking
   */
  function delegateRewards(address[] calldata _consensusAddrList, address _consensusAddrDst)
    external
    override
    notCandidateAdmin(_consensusAddrDst)
    returns (uint256 _amount)
  {
    return _delegateRewards(msg.sender, _consensusAddrList, _consensusAddrDst);
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
   *
   */
  function _delegate(
    address _poolAddr,
    address _user,
    uint256 _amount
  ) internal {
    uint256 _newBalance = _delegatedAmount[_poolAddr][_user] + _amount;
    _syncUserReward(_poolAddr, _user, _newBalance);

    ValidatorCandidate storage _candidate = _getCandidate(_poolAddr);
    _candidate.delegatedAmount += _amount;
    _delegatedAmount[_poolAddr][_user] = _newBalance;
    emit Delegated(_user, _poolAddr, _amount);
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
    address _poolAddr,
    address _user,
    uint256 _amount
  ) private {
    require(_delegatedAmount[_poolAddr][_user] >= _amount, "StakingManager: insufficient amount to undelegate");

    uint256 _newBalance = _delegatedAmount[_poolAddr][_user] - _amount;
    _syncUserReward(_poolAddr, _user, _newBalance);

    ValidatorCandidate storage _candidate = _getCandidate(_poolAddr);
    _candidate.delegatedAmount -= _amount;
    _delegatedAmount[_poolAddr][_user] = _newBalance;
    emit Undelegated(_user, _poolAddr, _amount);
  }

  /**
   * @dev Claims rewards from the pools `_poolAddrList`.
   *
   *@notice This function does not transfer reward to user.
   *
   * TODO: Check whether pool addr is in the candidate list. or add test for this fn.
   *
   */
  function _claimRewards(address _user, address[] calldata _poolAddrList) internal returns (uint256 _amount) {
    for (uint256 _i = 0; _i < _poolAddrList.length; _i++) {
      _amount += _claimReward(_poolAddrList[_i], _user);
    }
  }

  /**
   * @dev Claims the rewards and delegates them to the consensus address.
   */
  function _delegateRewards(
    address _user,
    address[] calldata _poolAddrList,
    address _poolAddrDst
  ) internal returns (uint256 _amount) {
    _amount = _claimRewards(_user, _poolAddrList);
    _delegate(_poolAddrDst, _user, _amount);
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                                  HELPER FUNCTIONS                                 //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Returns the validator candidate from storage form.
   *
   * Requirements:
   * - The candidate is already existed.
   *
   */
  function _getCandidate(address _consensusAddr) internal view virtual returns (ValidatorCandidate storage _candidate);

  /**
   * @dev Returns the bitwise negation of the candidate index in the response of function `getValidator Candidates()`.
   *
   * Requirements:
   * - The candidate is already existed.
   *
   */
  function _getCandidateIndex(address _consensusAddr) internal view virtual returns (uint256);

  /**
   * @dev Sets the candidate index.
   */
  function _setCandidateIndex(address _consensusAddr, uint256 _candidateIdx) internal virtual;

  /**
   * @dev Creates new validator candidate in the storage and returns its struct.
   */
  function _createValidatorCandidate(
    address _consensusAddr,
    address _candidateAdmin,
    address payable _treasuryAddr,
    uint256 _commissionRate
  ) internal virtual returns (ValidatorCandidate memory);
}
