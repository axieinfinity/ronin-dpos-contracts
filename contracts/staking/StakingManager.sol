// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../extensions/RONTransferHelper.sol";
import "../extensions/HasValidatorContract.sol";
import "../interfaces/IStaking.sol";
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

  modifier noEmptyValue() {
    require(msg.value > 0, "StakingManager: query with empty value");
    _;
  }

  modifier notPoolAdmin(PoolDetail storage _pool, address _delegator) {
    require(_pool.admin != _delegator, "StakingManager: delegator must not be the pool admin");
    _;
  }

  modifier onlyValidatorCandidate(address _poolAddr) {
    require(
      _validatorContract.isValidatorCandidate(_poolAddr),
      "StakingManager: method caller must not be the pool admin"
    );
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
    return _stakingPool[_poolAddr].delegatedAmount[_user];
  }

  /**
   * @inheritdoc IRewardPool
   */
  function totalBalance(address _poolAddr) public view override(IRewardPool, RewardCalculation) returns (uint256) {
    return _stakingPool[_poolAddr].totalBalance;
  }

  /**
   * @inheritdoc IRewardPool
   */
  function totalBalances(address[] calldata _poolList) public view override returns (uint256[] memory _balances) {
    _balances = new uint256[](_poolList.length);
    for (uint _i = 0; _i < _poolList.length; _i++) {
      _balances[_i] = totalBalance(_poolList[_i]);
    }
  }

  /**
   * @inheritdoc IStaking
   */
  function minValidatorBalance() public view virtual returns (uint256);

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
  ) external payable override nonReentrant {
    uint256 _amount = msg.value;
    address payable _candidateAdmin = payable(msg.sender);
    _proposeValidator(_candidateAdmin, _consensusAddr, _treasuryAddr, _commissionRate, _amount);

    PoolDetail storage _pool = _stakingPool[_consensusAddr];
    _pool.admin = _candidateAdmin;
    _pool.addr = _consensusAddr;
    _stake(_stakingPool[_consensusAddr], _candidateAdmin, _amount);
    emit ValidatorPoolAdded(_consensusAddr, _candidateAdmin);
  }

  /**
   * @inheritdoc IStaking
   */
  function stake(address _consensusAddr) external payable override noEmptyValue onlyValidatorCandidate(_consensusAddr) {
    _stake(_stakingPool[_consensusAddr], msg.sender, msg.value);
  }

  /**
   * @inheritdoc IStaking
   */
  function unstake(address _consensusAddr, uint256 _amount)
    external
    override
    nonReentrant
    onlyValidatorCandidate(_consensusAddr)
  {
    address _delegator = msg.sender;
    PoolDetail storage _pool = _stakingPool[_consensusAddr];
    uint256 _remainAmount = _pool.stakedAmount - _amount;
    require(_remainAmount >= minValidatorBalance(), "StakingManager: invalid staked amount left");

    _unstake(_pool, _delegator, _amount);
    require(_sendRON(payable(_delegator), _amount), "StakingManager: could not transfer RON");
  }

  /**
   * @inheritdoc IStaking
   */
  function renounce(address _consensusAddr) external onlyValidatorCandidate(_consensusAddr) {
    // TODO(Thor): implement this function
    revert("unimplemented");
  }

  /**
   * @dev Proposes a candidate to become a valdiator.
   *
   * Requirements:
   * - The validator length is not exceeded the total validator threshold `_maxValidatorCandidate`.
   * - The amount is larger than or equal to the minimum validator balance `_minValidatorBalance`.
   *
   */
  function _proposeValidator(
    address payable _candidateAdmin,
    address _consensusAddr,
    address payable _treasuryAddr,
    uint256 _commissionRate,
    uint256 _amount
  ) internal {
    require(_sendRON(_candidateAdmin, 0), "StakingManager: pool admin cannot receive RON");
    require(_sendRON(_treasuryAddr, 0), "StakingManager: treasury cannot receive RON");
    require(_amount >= minValidatorBalance(), "StakingManager: insufficient amount");

    _validatorContract.addValidatorCandidate(_consensusAddr, _treasuryAddr, _commissionRate);
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
    PoolDetail storage _pool,
    address _requester,
    uint256 _amount
  ) internal {
    require(_pool.admin == _requester, "StakingManager: requester must be the pool admin");
    _pool.stakedAmount += _amount;
    emit Staked(_pool.addr, _amount);

    _unsafeDelegate(_pool, _requester, _amount);
  }

  /**
   * @dev Withdraws the staked amount `_amount` for the validator candidate.
   *
   * Requirements:
   * - The address `_requester` must be the pool admin.
   * - The remain balance must be greater than the minimum validator candidate thresold `minValidatorBalance()`.
   *
   * Emits the `Unstaked` event.
   *
   */
  function _unstake(
    PoolDetail storage _pool,
    address _requester,
    uint256 _amount
  ) internal {
    require(_pool.admin == _requester, "StakingManager: requester must be the pool admin");
    require(_amount <= _pool.stakedAmount, "StakingManager: insufficient staked amount");

    _pool.stakedAmount -= _amount;
    emit Unstaked(_pool.addr, _amount);
    _unsafeUndelegate(_pool, _requester, _amount);
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                             FUNCTIONS FOR DELEGATOR                               //
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @inheritdoc IStaking
   */
  function delegate(address _consensusAddr) external payable noEmptyValue onlyValidatorCandidate(_consensusAddr) {
    _delegate(_stakingPool[_consensusAddr], msg.sender, msg.value);
  }

  /**
   * @inheritdoc IStaking
   */
  function undelegate(address _consensusAddr, uint256 _amount) external nonReentrant {
    // TODO: add bulk function to undelegate a list of consensus addresses
    address payable _delegator = payable(msg.sender);
    _undelegate(_stakingPool[_consensusAddr], _delegator, _amount);
    require(_sendRON(_delegator, _amount), "StakingManager: could not transfer RON");
  }

  /**
   * @inheritdoc IStaking
   */
  function redelegate(
    address _consensusAddrSrc,
    address _consensusAddrDst,
    uint256 _amount
  ) external nonReentrant {
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
  function claimRewards(address[] calldata _consensusAddrList) external nonReentrant returns (uint256 _amount) {
    _amount = _claimRewards(msg.sender, _consensusAddrList);
    require(_sendRON(payable(msg.sender), _amount), "StakingManager: could not transfer RON");
  }

  /**
   * @inheritdoc IStaking
   */
  function delegateRewards(address[] calldata _consensusAddrList, address _consensusAddrDst)
    external
    override
    nonReentrant
    returns (uint256 _amount)
  {
    return _delegateRewards(msg.sender, _consensusAddrList, _consensusAddrDst);
  }

  /**
   * @dev Delegates from a validator address.
   *
   * Emits the `Delegated` event.
   *
   * Note: This function does not verify the `msg.value` with the amount.
   *
   */
  function _unsafeDelegate(
    PoolDetail storage _pool,
    address _delegator,
    uint256 _amount
  ) internal {
    uint256 _newBalance = _pool.delegatedAmount[_delegator] + _amount;
    _syncUserReward(_pool.addr, _delegator, _newBalance);

    _pool.totalBalance += _amount;
    _pool.delegatedAmount[_delegator] = _newBalance;
    emit Delegated(_delegator, _pool.addr, _amount);
  }

  /**
   * @dev See `_unsafeDelegate`.
   *
   * Requirements:
   * - The delegator is not the pool admin.
   *
   */
  function _delegate(
    PoolDetail storage _pool,
    address _delegator,
    uint256 _amount
  ) internal notPoolAdmin(_pool, _delegator) {
    _unsafeDelegate(_pool, _delegator, _amount);
  }

  /**
   * @dev Undelegates from a validator address.
   *
   * Requirements:
   * - The delegated amount is larger than or equal to the undelegated amount.
   *
   * Emits the `Undelegated` event.
   *
   * Note: Consider transferring back the amount of RON after calling this function.
   *
   */
  function _unsafeUndelegate(
    PoolDetail storage _pool,
    address _delegator,
    uint256 _amount
  ) private {
    require(_pool.delegatedAmount[_delegator] >= _amount, "StakingManager: insufficient amount to undelegate");

    uint256 _newBalance = _pool.delegatedAmount[_delegator] - _amount;
    _syncUserReward(_pool.addr, _delegator, _newBalance);
    _pool.totalBalance -= _amount;
    _pool.delegatedAmount[_delegator] = _newBalance;
    emit Undelegated(_delegator, _pool.addr, _amount);
  }

  /**
   * @dev See `_unsafeUndelegate`.
   *
   * Requirements:
   * - The delegator is not the pool admin.
   *
   */
  function _undelegate(
    PoolDetail storage _pool,
    address _delegator,
    uint256 _amount
  ) private notPoolAdmin(_pool, _delegator) {
    _unsafeUndelegate(_pool, _delegator, _amount);
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
