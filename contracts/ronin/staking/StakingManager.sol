// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../../extensions/RONTransferHelper.sol";
import "../../extensions/collections/HasValidatorContract.sol";
import "../../interfaces/IStaking.sol";
import "../../libraries/Math.sol";
import "./RewardCalculation.sol";

abstract contract StakingManager is
  IStaking,
  RONTransferHelper,
  ReentrancyGuard,
  RewardCalculation,
  HasValidatorContract
{
  /// @dev Mapping from pool address => staking pool detail
  mapping(address => PoolDetail) internal _stakingPool;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private ______gap;

  function _minPeriodsToUndelegate000() internal virtual returns(uint256);

  modifier noEmptyValue() {
    require(msg.value > 0, "StakingManager: query with empty value");
    _;
  }

  modifier notPoolAdmin(PoolDetail storage _pool, address _delegator) {
    require(_pool.admin != _delegator, "StakingManager: delegator must not be the pool admin");
    _;
  }

  modifier onlyPoolAdmin(PoolDetail storage _pool, address _requester) {
    require(_pool.admin == _requester, "StakingManager: requester must be the pool admin");
    _;
  }

  modifier poolExists(address _poolAddr) {
    require(_validatorContract.isValidatorCandidate(_poolAddr), "StakingManager: query for non-existent pool");
    _;
  }

  /**
   * @inheritdoc IRewardPool
   */
  function stakingAmountOf(address _poolAddr, address _user)
    public
    view
    override(IRewardPool, RewardCalculation)
    returns (uint256)
  {
    return _stakingPool[_poolAddr].delegatingAmount[_user];
  }

  /**
   * @inheritdoc IRewardPool
   */
  function bulkStakingAmountOf(address[] calldata _poolAddrs, address[] calldata _userList)
    external
    view
    override
    returns (uint256[] memory _stakingAmounts)
  {
    require(_poolAddrs.length > 0 && _poolAddrs.length == _userList.length, "StakingManager: invalid input array");
    _stakingAmounts = new uint256[](_poolAddrs.length);
    for (uint _i = 0; _i < _stakingAmounts.length; _i++) {
      _stakingAmounts[_i] = _stakingPool[_poolAddrs[_i]].delegatingAmount[_userList[_i]];
    }
  }

  /**
   * @inheritdoc IRewardPool
   */
  function stakingTotal(address _poolAddr) public view override(IRewardPool, RewardCalculation) returns (uint256) {
    return _stakingPool[_poolAddr].stakingTotal;
  }

  /**
   * @inheritdoc IRewardPool
   */
  function bulkStakingTotal(address[] calldata _poolList)
    public
    view
    override
    returns (uint256[] memory _stakingAmounts)
  {
    _stakingAmounts = new uint256[](_poolList.length);
    for (uint _i = 0; _i < _poolList.length; _i++) {
      _stakingAmounts[_i] = stakingTotal(_poolList[_i]);
    }
  }

  /**
   * @inheritdoc IStaking
   */
  function minValidatorStakingAmount() public view virtual returns (uint256);

  ///////////////////////////////////////////////////////////////////////////////////////
  //                          FUNCTIONS FOR VALIDATOR CANDIDATE                        //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc IStaking
   */
  function applyValidatorCandidate(
    address _candidateAdmin,
    address _consensusAddr,
    address payable _treasuryAddr,
    address _bridgeOperatorAddr,
    uint256 _commissionRate
  ) external payable override nonReentrant {
    uint256 _amount = msg.value;
    address payable _poolAdmin = payable(msg.sender);
    _applyValidatorCandidate(
      _poolAdmin,
      _candidateAdmin,
      _consensusAddr,
      _treasuryAddr,
      _bridgeOperatorAddr,
      _commissionRate,
      _amount
    );

    PoolDetail storage _pool = _stakingPool[_consensusAddr];
    _pool.admin = _poolAdmin;
    _pool.addr = _consensusAddr;
    _stake(_stakingPool[_consensusAddr], _poolAdmin, _amount);
    emit PoolApproved(_consensusAddr, _poolAdmin);
  }

  /**
   * @inheritdoc IStaking
   */
  function stake(address _consensusAddr) external payable override noEmptyValue poolExists(_consensusAddr) {
    _stake(_stakingPool[_consensusAddr], msg.sender, msg.value);
  }

  /**
   * @inheritdoc IStaking
   */
  function unstake(address _consensusAddr, uint256 _amount) external override nonReentrant poolExists(_consensusAddr) {
    require(_amount > 0, "StakingManager: invalid amount");
    address _delegator = msg.sender;
    PoolDetail storage _pool = _stakingPool[_consensusAddr];
    uint256 _remainAmount = _pool.stakingAmount - _amount;
    require(_remainAmount >= minValidatorStakingAmount(), "StakingManager: invalid staking amount left");

    _unstake(_pool, _delegator, _amount);
    require(_sendRON(payable(_delegator), _amount), "StakingManager: could not transfer RON");
  }

  /**
   * @inheritdoc IStaking
   */
  function requestRenounce(address _consensusAddr)
    external
    poolExists(_consensusAddr)
    onlyPoolAdmin(_stakingPool[_consensusAddr], msg.sender)
  {
    _validatorContract.requestRevokeCandidate(_consensusAddr);
  }

  /**
   * @dev Proposes a candidate to become a validator.
   *
   * Requirements:
   * - The pool admin is able to receive RON.
   * - The treasury is able to receive RON.
   * - The amount is larger than or equal to the minimum validator staking amount `minValidatorStakingAmount()`.
   *
   * @param _candidateAdmin the candidate admin will be stored in the validator contract, used for calling function that affects
   * to its candidate. IE: scheduling maintenance.
   *
   */
  function _applyValidatorCandidate(
    address payable _poolAdmin,
    address _candidateAdmin,
    address _consensusAddr,
    address payable _treasuryAddr,
    address _bridgeOperatorAddr,
    uint256 _commissionRate,
    uint256 _amount
  ) internal {
    require(_sendRON(_poolAdmin, 0), "StakingManager: pool admin cannot receive RON");
    require(_sendRON(_treasuryAddr, 0), "StakingManager: treasury cannot receive RON");
    require(_amount >= minValidatorStakingAmount(), "StakingManager: insufficient amount");

    _validatorContract.grantValidatorCandidate(
      _candidateAdmin,
      _consensusAddr,
      _treasuryAddr,
      _bridgeOperatorAddr,
      _commissionRate
    );
  }

  /**
   * @dev Stakes for the validator candidate.
   *
   * Requirements:
   * - The address `_requester` must be the pool admin.
   *
   * Emits the `Staked` event.
   *
   */
  function _stake(
    PoolDetail storage _pool,
    address _requester,
    uint256 _amount
  ) internal onlyPoolAdmin(_pool, _requester) {
    _pool.stakingAmount += _amount;
    _changeDelegatingAmount(_pool, _requester, _pool.stakingAmount, _pool.stakingTotal + _amount);
    _pool.lastDelegatingPeriod[_requester] = _currentPeriod();
    emit Staked(_pool.addr, _amount);
  }

  /**
   * @dev Withdraws the staking amount `_amount` for the validator candidate.
   *
   * Requirements:
   * - The address `_requester` must be the pool admin.
   *
   * Emits the `Unstaked` event.
   *
   */
  function _unstake(
    PoolDetail storage _pool,
    address _requester,
    uint256 _amount
  ) internal onlyPoolAdmin(_pool, _requester) {
    require(_amount <= _pool.stakingAmount, "StakingManager: insufficient staking amount");
    require(
      _pool.lastDelegatingPeriod[_requester] + _minPeriodsToUndelegate000() < _currentPeriod(),
      "StakingManager: unstake too early"
    );

    _pool.stakingAmount -= _amount;
    _changeDelegatingAmount(_pool, _requester, _pool.stakingAmount, _pool.stakingTotal - _amount);
    emit Unstaked(_pool.addr, _amount);
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                             FUNCTIONS FOR DELEGATOR                               //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc IStaking
   */
  function delegate(address _consensusAddr) external payable noEmptyValue poolExists(_consensusAddr) {
    _delegate(_stakingPool[_consensusAddr], msg.sender, msg.value);
  }

  /**
   * @inheritdoc IStaking
   */
  function undelegate(address _consensusAddr, uint256 _amount) external nonReentrant {
    address payable _delegator = payable(msg.sender);
    _undelegate(_stakingPool[_consensusAddr], _delegator, _amount);
    require(_sendRON(_delegator, _amount), "StakingManager: could not transfer RON");
  }

  /**
   * @inheritdoc IStaking
   */
  function bulkUndelegate(address[] calldata _consensusAddrs, uint256[] calldata _amounts) external nonReentrant {
    require(
      _consensusAddrs.length > 0 && _consensusAddrs.length == _amounts.length,
      "StakingManager: invalid array length"
    );

    address payable _delegator = payable(msg.sender);
    uint256 _total;

    for (uint _i = 0; _i < _consensusAddrs.length; _i++) {
      _total += _amounts[_i];
      _undelegate(_stakingPool[_consensusAddrs[_i]], _delegator, _amounts[_i]);
    }

    require(_sendRON(_delegator, _total), "StakingManager: could not transfer RON");
  }

  /**
   * @inheritdoc IStaking
   */
  function redelegate(
    address _consensusAddrSrc,
    address _consensusAddrDst,
    uint256 _amount
  ) external nonReentrant poolExists(_consensusAddrDst) {
    address _delegator = msg.sender;
    _undelegate(_stakingPool[_consensusAddrSrc], _delegator, _amount);
    _delegate(_stakingPool[_consensusAddrDst], _delegator, _amount);
  }

  /**
   * @inheritdoc IStaking
   */
  function getRewards(address _user, address[] calldata _poolAddrList)
    external
    view
    returns (uint256[] memory _rewards)
  {
    address _consensusAddr;
    uint256 _period = _validatorContract.currentPeriod();
    _rewards = new uint256[](_poolAddrList.length);

    for (uint256 _i = 0; _i < _poolAddrList.length; _i++) {
      _consensusAddr = _poolAddrList[_i];
      _rewards[_i] = _getReward(_consensusAddr, _user, _period, stakingAmountOf(_consensusAddr, _user));
    }
  }

  /**
   * @inheritdoc IStaking
   */
  function claimRewards(address[] calldata _consensusAddrList) external nonReentrant returns (uint256 _amount) {
    _amount = _claimRewards(msg.sender, _consensusAddrList);
    _transferRON(payable(msg.sender), _amount);
  }

  /**
   * @inheritdoc IStaking
   */
  function delegateRewards(address[] calldata _consensusAddrList, address _consensusAddrDst)
    external
    override
    nonReentrant
    poolExists(_consensusAddrDst)
    returns (uint256 _amount)
  {
    return _delegateRewards(msg.sender, _consensusAddrList, _consensusAddrDst);
  }

  /**
   * @dev Delegates from a validator address.
   *
   * Requirements:
   * - The delegator is not the pool admin.
   *
   * Emits the `Delegated` event.
   *
   * Note: This function does not verify the `msg.value` with the amount.
   *
   */
  function _delegate(
    PoolDetail storage _pool,
    address _delegator,
    uint256 _amount
  ) internal notPoolAdmin(_pool, _delegator) {
    _changeDelegatingAmount(
      _pool,
      _delegator,
      _pool.delegatingAmount[_delegator] + _amount,
      _pool.stakingTotal + _amount
    );
    _pool.lastDelegatingPeriod[_delegator] = _currentPeriod();
    emit Delegated(_delegator, _pool.addr, _amount);
  }

  /**
   * @dev Undelegates from a validator address.
   *
   * Requirements:
   * - The delegator is not the pool admin.
   * - The amount is larger than 0.
   * - The delegating amount is larger than or equal to the undelegating amount.
   *
   * Emits the `Undelegated` event.
   *
   * Note: Consider transferring back the amount of RON after calling this function.
   *
   */
  function _undelegate(
    PoolDetail storage _pool,
    address _delegator,
    uint256 _amount
  ) private notPoolAdmin(_pool, _delegator) {
    require(_amount > 0, "StakingManager: invalid amount");
    require(_pool.delegatingAmount[_delegator] >= _amount, "StakingManager: insufficient amount to undelegate");
    require(
      _pool.lastDelegatingPeriod[_delegator] + _minPeriodsToUndelegate000() < _currentPeriod(),
      "StakingManager: unstake too early"
    );
    _changeDelegatingAmount(
      _pool,
      _delegator,
      _pool.delegatingAmount[_delegator] - _amount,
      _pool.stakingTotal - _amount
    );
    emit Undelegated(_delegator, _pool.addr, _amount);
  }

  /**
   * @dev Changes the delelgate amount.
   */
  function _changeDelegatingAmount(
    PoolDetail storage _pool,
    address _delegator,
    uint256 _newDelegatingAmount,
    uint256 _newStakingTotal
  ) internal {
    _syncUserReward(_pool.addr, _delegator, _newDelegatingAmount);
    _pool.stakingTotal = _newStakingTotal;
    _pool.delegatingAmount[_delegator] = _newDelegatingAmount;
  }

  /**
   * @dev Claims rewards from the pools `_poolAddrList`.
   * Note: This function does not transfer reward to user.
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
    _delegate(_stakingPool[_poolAddrDst], _user, _amount);
  }
}
