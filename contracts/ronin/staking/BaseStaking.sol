// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../../extensions/RONTransferHelper.sol";
import "../../extensions/collections/HasContracts.sol";
import "../../interfaces/staking/IBaseStaking.sol";
import "../../interfaces/validator/IRoninValidatorSet.sol";
import "../../libraries/Math.sol";
import { HasValidatorDeprecated } from "../../utils/DeprecatedSlots.sol";
import "./RewardCalculation.sol";

abstract contract BaseStaking is
  RONTransferHelper,
  ReentrancyGuard,
  RewardCalculation,
  HasContracts,
  IBaseStaking,
  HasValidatorDeprecated
{
  /// @dev Mapping from pool address => staking pool detail
  mapping(address => PoolDetail) internal _stakingPool;

  /// @dev The cooldown time in seconds to undelegate from the last timestamp (s)he delegated.
  uint256 internal _cooldownSecsToUndelegate;
  /// @dev The number of seconds that a candidate must wait to be revoked and take the self-staking amount back.
  uint256 internal _waitingSecsToRevoke;

  /// @dev Mapping from admin address of an active pool => consensus address.
  mapping(address => address) internal _adminOfActivePoolMapping;
  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[49] private ______gap;

  modifier noEmptyValue() {
    _requireValue();
    _;
  }

  modifier anyExceptPoolAdmin(PoolDetail storage _pool, address _delegator) {
    _anyExceptPoolAdmin(_pool, _delegator);
    _;
  }

  modifier onlyPoolAdmin(PoolDetail storage _pool, address _requester) {
    _requirePoolAdmin(_pool, _requester);
    _;
  }

  modifier poolIsActive(address _poolAddr) {
    _poolIsActive(_poolAddr);
    _;
  }

  function _requireValue() private view {
    if (msg.value == 0) revert ErrZeroValue();
  }

  function _requirePoolAdmin(PoolDetail storage _pool, address _requester) private view {
    if (_pool.admin != _requester) revert ErrOnlyPoolAdminAllowed();
  }

  function _anyExceptPoolAdmin(PoolDetail storage _pool, address _delegator) private view {
    if (_pool.admin == _delegator) revert ErrPoolAdminForbidden();
  }

  function _poolIsActive(address _poolAddr) private view {
    if (!IRoninValidatorSet(getContract(ContractType.VALIDATOR)).isValidatorCandidate(_poolAddr))
      revert ErrInactivePool(_poolAddr);
  }

  /**
   * @inheritdoc IBaseStaking
   */
  function isAdminOfActivePool(address _poolAdminAddr) public view override returns (bool) {
    return _adminOfActivePoolMapping[_poolAdminAddr] != address(0);
  }

  /**
   * @inheritdoc IBaseStaking
   */
  function getPoolAddressOf(address _poolAdminAddr) external view override returns (address) {
    return _adminOfActivePoolMapping[_poolAdminAddr];
  }

  /**
   * @inheritdoc IBaseStaking
   */
  function getPoolDetail(
    address _poolAddr
  ) external view returns (address _admin, uint256 _stakingAmount, uint256 _stakingTotal) {
    PoolDetail storage _pool = _stakingPool[_poolAddr];
    return (_pool.admin, _pool.stakingAmount, _pool.stakingTotal);
  }

  /**
   * @inheritdoc IBaseStaking
   */
  function getManySelfStakings(address[] calldata _pools) external view returns (uint256[] memory _selfStakings) {
    _selfStakings = new uint256[](_pools.length);
    for (uint _i = 0; _i < _pools.length; ) {
      _selfStakings[_i] = _stakingPool[_pools[_i]].stakingAmount;

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @inheritdoc IRewardPool
   */
  function getStakingTotal(address _poolAddr) public view override returns (uint256) {
    return _stakingPool[_poolAddr].stakingTotal;
  }

  /**
   * @inheritdoc IRewardPool
   */
  function getManyStakingTotals(
    address[] calldata _poolList
  ) public view override returns (uint256[] memory _stakingAmounts) {
    _stakingAmounts = new uint256[](_poolList.length);
    for (uint _i = 0; _i < _poolList.length; ) {
      _stakingAmounts[_i] = getStakingTotal(_poolList[_i]);

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @inheritdoc IRewardPool
   */
  function getStakingAmount(address _poolAddr, address _user) public view override returns (uint256) {
    return _stakingPool[_poolAddr].delegatingAmount[_user];
  }

  /**
   * @inheritdoc IRewardPool
   */
  function getManyStakingAmounts(
    address[] calldata _poolAddrs,
    address[] calldata _userList
  ) external view override returns (uint256[] memory _stakingAmounts) {
    if (_poolAddrs.length != _userList.length) revert ErrInvalidArrays();
    _stakingAmounts = new uint256[](_poolAddrs.length);
    for (uint _i = 0; _i < _stakingAmounts.length; ) {
      _stakingAmounts[_i] = _stakingPool[_poolAddrs[_i]].delegatingAmount[_userList[_i]];

      unchecked {
        ++_i;
      }
    }
  }

  /**
   * @inheritdoc IBaseStaking
   */
  function cooldownSecsToUndelegate() external view returns (uint256) {
    return _cooldownSecsToUndelegate;
  }

  /**
   * @inheritdoc IBaseStaking
   */
  function waitingSecsToRevoke() external view returns (uint256) {
    return _waitingSecsToRevoke;
  }

  /**
   * @inheritdoc IBaseStaking
   */
  function setCooldownSecsToUndelegate(uint256 _cooldownSecs) external override onlyAdmin {
    _setCooldownSecsToUndelegate(_cooldownSecs);
  }

  /**
   * @inheritdoc IBaseStaking
   */
  function setWaitingSecsToRevoke(uint256 _secs) external override onlyAdmin {
    _setWaitingSecsToRevoke(_secs);
  }

  /**
   * @dev Sets the minium number of seconds to undelegate.
   *
   * Emits the event `CooldownSecsToUndelegateUpdated`.
   *
   */
  function _setCooldownSecsToUndelegate(uint256 _cooldownSecs) internal {
    _cooldownSecsToUndelegate = _cooldownSecs;
    emit CooldownSecsToUndelegateUpdated(_cooldownSecs);
  }

  /**
   * @dev Sets the number of seconds that a candidate must wait to be revoked.
   *
   * Emits the event `WaitingSecsToRevokeUpdated`.
   *
   */
  function _setWaitingSecsToRevoke(uint256 _secs) internal {
    _waitingSecsToRevoke = _secs;
    emit WaitingSecsToRevokeUpdated(_secs);
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
