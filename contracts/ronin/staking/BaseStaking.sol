// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../../extensions/RONTransferHelper.sol";
import "../../extensions/collections/HasContracts.sol";
import "../../interfaces/staking/IBaseStaking.sol";
import "../../interfaces/validator/IRoninValidatorSet.sol";
import "../../interfaces/IProfile.sol";
import "../../libraries/Math.sol";
import { HasValidatorDeprecated } from "../../utils/DeprecatedSlots.sol";
import "./RewardCalculation.sol";
import { TPoolId, TConsensus } from "../../udvts/Types.sol";

abstract contract BaseStaking is
  RONTransferHelper,
  ReentrancyGuard,
  RewardCalculation,
  HasContracts,
  IBaseStaking,
  HasValidatorDeprecated
{
  /// @dev Mapping from pool address => staking pool detail
  mapping(address => PoolDetail) internal _poolDetail;

  /// @dev The cooldown time in seconds to undelegate from the last timestamp (s)he delegated.
  uint256 internal _cooldownSecsToUndelegate;
  /// @dev The number of seconds that a candidate must wait to be revoked and take the self-staking amount back.
  uint256 internal _waitingSecsToRevoke;

  /// @dev Mapping from admin address of an active pool => pool id.
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

  modifier anyExceptPoolAdmin(PoolDetail storage _pool, address delegator) {
    _anyExceptPoolAdmin(_pool, delegator);
    _;
  }

  modifier onlyPoolAdmin(PoolDetail storage _pool, address requester) {
    _requirePoolAdmin(_pool, requester);
    _;
  }

  modifier poolOfConsensusIsActive(TConsensus consensusAddr) {
    _poolOfConsensusIsActive(consensusAddr);
    _;
  }

  function _requireValue() private view {
    if (msg.value == 0) revert ErrZeroValue();
  }

  function _requirePoolAdmin(PoolDetail storage _pool, address requester) private view {
    if (_pool.admin != requester) revert ErrOnlyPoolAdminAllowed();
  }

  function _anyExceptPoolAdmin(PoolDetail storage _pool, address delegator) private view {
    if (_pool.admin == delegator) revert ErrPoolAdminForbidden();
  }

  function _poolOfConsensusIsActive(TConsensus consensusAddr) private view {
    // TODO: to wrap in callee
    if (!IRoninValidatorSet(getContract(ContractType.VALIDATOR)).isValidatorCandidate(TConsensus.unwrap(consensusAddr)))
      revert ErrInactivePool(consensusAddr, _convertC2P(consensusAddr));
  }

  /**
   * @inheritdoc IBaseStaking
   */
  function isAdminOfActivePool(address admin) public view override returns (bool) {
    return _adminOfActivePoolMapping[admin] != address(0);
  }

  /**
   * @inheritdoc IBaseStaking
   */
  function getPoolAddressOf(address admin) external view override returns (address) {
    return _adminOfActivePoolMapping[admin];
  }

  /**
   * @inheritdoc IBaseStaking
   */
  function getPoolDetail(
    TConsensus consensusAddr
  ) external view returns (address admin, uint256 stakingAmount, uint256 stakingTotal) {
    address poolId = _convertC2P(consensusAddr);
    return _getPoolDetailById(poolId);
  }

  function getPoolDetailById(
    address poolId
  ) external view returns (address admin, uint256 stakingAmount, uint256 stakingTotal) {
    return _getPoolDetailById(poolId);
  }

  function _getPoolDetailById(
    address poolId
  ) internal view returns (address admin, uint256 stakingAmount, uint256 stakingTotal) {
    PoolDetail storage _pool = _poolDetail[poolId];
    return (_pool.admin, _pool.stakingAmount, _pool.stakingTotal);
  }

  /**
   * @inheritdoc IBaseStaking
   */
  function getManySelfStakings(
    TConsensus[] calldata consensusAddrs
  ) external view returns (uint256[] memory selfStakings_) {
    address[] memory poolIds = _convertManyC2P(consensusAddrs);
    return _getManySelfStakingsById(poolIds);
  }

  /**
   * @inheritdoc IBaseStaking
   */
  function getManySelfStakingsById(address[] calldata poolIds) external view returns (uint256[] memory selfStakings_) {
    return _getManySelfStakingsById(poolIds);
  }

  /**
   * @dev Query many self staking amount by list `poolIds`.
   */
  function _getManySelfStakingsById(address[] memory poolIds) internal view returns (uint256[] memory selfStakings_) {
    selfStakings_ = new uint256[](poolIds.length);
    for (uint i = 0; i < poolIds.length; ) {
      selfStakings_[i] = _poolDetail[poolIds[i]].stakingAmount;

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @inheritdoc IRewardPool
   */
  function getStakingTotal(TConsensus consensusAddr) external view override returns (uint256) {
    address poolId = _convertC2P(consensusAddr);
    return _getStakingTotal(poolId);
  }

  /**
   * @inheritdoc IRewardPool
   */
  function getManyStakingTotals(
    TConsensus[] calldata consensusAddrs
  ) external view override returns (uint256[] memory stakingAmounts_) {
    address[] memory poolIds = _convertManyC2P(consensusAddrs);
    return _getManyStakingTotalsById(poolIds);
  }

  /**
   * @inheritdoc IRewardPool
   */
  function getManyStakingTotalsById(
    address[] calldata poolIds
  ) external view override returns (uint256[] memory stakingAmounts_) {
    return _getManyStakingTotalsById(poolIds);
  }

  function _getManyStakingTotalsById(
    address[] memory poolIds
  ) internal view returns (uint256[] memory stakingAmounts_) {
    stakingAmounts_ = new uint256[](poolIds.length);
    for (uint i = 0; i < poolIds.length; ) {
      stakingAmounts_[i] = _getStakingTotal(poolIds[i]);

      unchecked {
        ++i;
      }
    }
  }

  function _getStakingTotal(address poolId) internal view override returns (uint256) {
    return _poolDetail[poolId].stakingTotal;
  }

  /**
   * @inheritdoc IRewardPool
   */
  function getStakingAmount(TConsensus consensusAddr, address user) external view override returns (uint256) {
    address poolId = _convertC2P(consensusAddr);
    return _getStakingAmount(poolId, user);
  }

  /**
   * @inheritdoc IRewardPool
   */
  function getManyStakingAmounts(
    TConsensus[] calldata consensusAddrs,
    address[] calldata userList
  ) external view override returns (uint256[] memory stakingAmounts) {
    address[] memory poolIds = _convertManyC2P(consensusAddrs);
    return _getManyStakingAmountsById(poolIds, userList);
  }

  function getManyStakingAmountsById(
    address[] calldata poolIds,
    address[] calldata userList
  ) external view returns (uint256[] memory stakingAmounts) {
    return _getManyStakingAmountsById(poolIds, userList);
  }

  function _getManyStakingAmountsById(
    address[] memory poolIds,
    address[] memory userList
  ) internal view returns (uint256[] memory stakingAmounts) {
    if (poolIds.length != userList.length) revert ErrInvalidArrays();
    stakingAmounts = new uint256[](poolIds.length);
    for (uint i = 0; i < stakingAmounts.length; ) {
      stakingAmounts[i] = _getStakingAmount(poolIds[i], userList[i]);

      unchecked {
        ++i;
      }
    }
  }

  function _getStakingAmount(address poolId, address user) internal view override returns (uint256) {
    return _poolDetail[poolId].delegatingAmount[user];
  }

  function _convertC2P(TConsensus consensusAddr) internal view returns (address) {
    return IProfile(getContract(ContractType.PROFILE)).getConsensus2Id(consensusAddr);
  }

  function _convertManyC2P(TConsensus[] memory consensusAddrs) internal view returns (address[] memory) {
    return IProfile(getContract(ContractType.PROFILE)).getManyConsensus2Id(consensusAddrs);
    // return _profileContract.getManyConsensus2Id(consensusAddrs);
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
  function setCooldownSecsToUndelegate(uint256 cooldownSecs) external override onlyAdmin {
    _setCooldownSecsToUndelegate(cooldownSecs);
  }

  /**
   * @inheritdoc IBaseStaking
   */
  function setWaitingSecsToRevoke(uint256 secs) external override onlyAdmin {
    _setWaitingSecsToRevoke(secs);
  }

  /**
   * @dev Sets the minium number of seconds to undelegate.
   *
   * Emits the event `CooldownSecsToUndelegateUpdated`.
   *
   */
  function _setCooldownSecsToUndelegate(uint256 cooldownSecs) internal {
    _cooldownSecsToUndelegate = cooldownSecs;
    emit CooldownSecsToUndelegateUpdated(cooldownSecs);
  }

  /**
   * @dev Sets the number of seconds that a candidate must wait to be revoked.
   *
   * Emits the event `WaitingSecsToRevokeUpdated`.
   *
   */
  function _setWaitingSecsToRevoke(uint256 secs) internal {
    _waitingSecsToRevoke = secs;
    emit WaitingSecsToRevokeUpdated(secs);
  }

  /**
   * @dev Changes the delegate amount.
   */
  function _changeDelegatingAmount(
    PoolDetail storage _pool,
    address delegator,
    uint256 newDelegatingAmount,
    uint256 newStakingTotal
  ) internal {
    _syncUserReward(_pool.id, delegator, newDelegatingAmount);
    _pool.stakingTotal = newStakingTotal;
    _pool.delegatingAmount[delegator] = newDelegatingAmount;
  }

  function _profileContract() internal view returns (IProfile) {
    return IProfile(getContract(ContractType.PROFILE));
  }
}
