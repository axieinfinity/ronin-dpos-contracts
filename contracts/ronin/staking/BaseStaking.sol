// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../../extensions/RONTransferHelper.sol";
import "../../extensions/collections/HasValidatorContract.sol";
import "../../interfaces/staking/IBaseStaking.sol";
import "../../libraries/Math.sol";
import "./RewardCalculation.sol";

abstract contract BaseStaking is
  RONTransferHelper,
  ReentrancyGuard,
  RewardCalculation,
  HasValidatorContract,
  IBaseStaking
{
  /// @dev Mapping from pool address => staking pool detail
  mapping(address => PoolDetail) internal _stakingPool;

  /// @dev The minium number of seconds to undelegate from the last timestamp (s)he delegated.
  uint256 internal _minSecsToUndelegate;
  /// @dev the number of seconds that a candidate must wait to be revoked and take the self-staking amount back.
  uint256 internal _secsForRevoking;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private ______gap;

  modifier noEmptyValue() {
    require(msg.value > 0, "BaseStaking: query with empty value");
    _;
  }

  modifier notPoolAdmin(PoolDetail storage _pool, address _delegator) {
    require(_pool.admin != _delegator, "BaseStaking: delegator must not be the pool admin");
    _;
  }

  modifier onlyPoolAdmin(PoolDetail storage _pool, address _requester) {
    require(_pool.admin == _requester, "BaseStaking: requester must be the pool admin");
    _;
  }

  modifier poolExists(address _poolAddr) {
    require(_validatorContract.isValidatorCandidate(_poolAddr), "BaseStaking: query for non-existent pool");
    _;
  }

  /**
   * @inheritdoc IRewardPool
   */
  function stakingAmountOf(address _poolAddr, address _user) public view override returns (uint256) {
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
    require(_poolAddrs.length > 0 && _poolAddrs.length == _userList.length, "BaseStaking: invalid input array");
    _stakingAmounts = new uint256[](_poolAddrs.length);
    for (uint _i = 0; _i < _stakingAmounts.length; _i++) {
      _stakingAmounts[_i] = _stakingPool[_poolAddrs[_i]].delegatingAmount[_userList[_i]];
    }
  }

  /**
   * @inheritdoc IRewardPool
   */
  function stakingTotal(address _poolAddr) public view override returns (uint256) {
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
   * @inheritdoc IBaseStaking
   */
  function minSecsToUndelegate() external view returns (uint256) {
    return _minSecsToUndelegate;
  }

  /**
   * @inheritdoc IBaseStaking
   */
  function secsForRevoking() external view returns (uint256) {
    return _secsForRevoking;
  }

  /**
   * @inheritdoc IBaseStaking
   */
  function setMinSecsToUndelegate(uint256 _minSecs) external override onlyAdmin {
    _setMinSecsToUndelegate(_minSecs);
  }

  /**
   * @inheritdoc IBaseStaking
   */
  function setSecsForRevoking(uint256 _secs) external override onlyAdmin {
    _setSecsForRevoking(_secs);
  }

  /**
   * @dev Sets the minium number of seconds to undelegate.
   *
   * Emits the event `MinSecsToUndelegateUpdated`.
   *
   */
  function _setMinSecsToUndelegate(uint256 _minSecs) internal {
    _minSecsToUndelegate = _minSecs;
    emit MinSecsToUndelegateUpdated(_minSecs);
  }

  /**
   * @dev Sets the number of seconds that a candidate must wait to be revoked.
   *
   * Emits the event `SecsForRevokingUpdated`.
   *
   */
  function _setSecsForRevoking(uint256 _secs) internal {
    _secsForRevoking = _secs;
    emit SecsForRevokingUpdated(_secs);
  }

  /**
   * @dev Changes the delegate amount.
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
}
