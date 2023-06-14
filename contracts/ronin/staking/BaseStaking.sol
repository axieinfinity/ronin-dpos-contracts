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

  modifier anyExceptPoolAdmin(PoolDetail storage _pool, address delegator) {
    _anyExceptPoolAdmin(_pool, delegator);
    _;
  }

  modifier onlyPoolAdmin(PoolDetail storage _pool, address requester) {
    _requirePoolAdmin(_pool, requester);
    _;
  }

  modifier poolOfConsensusIsActive(address consensusAddr) {
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

  function _poolOfConsensusIsActive(address consensusAddr) private view {
    if (!IRoninValidatorSet(getContract(ContractType.VALIDATOR)).isValidatorCandidate(consensusAddr))
      revert ErrInactivePool(consensusAddr);
  }

  /**
   * @inheritdoc IBaseStaking
   */
  function isAdminOfActivePool(address poolAdminAddr) public view override returns (bool) {
    return _adminOfActivePoolMapping[poolAdminAddr] != address(0);
  }

  /**
   * @inheritdoc IBaseStaking
   */
  function getPoolAddressOf(address poolAdminAddr) external view override returns (address) {
    return _adminOfActivePoolMapping[poolAdminAddr];
  }

  /**
   * @inheritdoc IBaseStaking
   */
  function getPoolDetail(
    address poolId
  ) external view returns (address admin, uint256 stakingAmount, uint256 stakingTotal) {
    PoolDetail storage _pool = _poolDetail[poolId];
    return (_pool.admin, _pool.stakingAmount, _pool.stakingTotal);
  }

  /**
   * @inheritdoc IBaseStaking
   */
  function getManySelfStakings(address[] calldata poolIds) external view returns (uint256[] memory selfStakings_) {
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
  function getStakingTotal(address consensusAddr) public view override returns (uint256) {
    address poolId = _unwrapC2P(consensusAddr);
    return _poolDetail[poolId].stakingTotal;
  }

  /**
   * @inheritdoc IRewardPool
   */
  function getManyStakingTotals(
    address[] calldata consensusAddrs
  ) public view override returns (uint256[] memory stakingAmounts_) {
    stakingAmounts_ = new uint256[](consensusAddrs.length);
    for (uint i = 0; i < consensusAddrs.length; ) {
      stakingAmounts_[i] = getStakingTotal(consensusAddrs[i]);

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @inheritdoc IRewardPool
   */
  function getStakingAmount(address poolId, address user) public view override returns (uint256) {
    return _poolDetail[poolId].delegatingAmount[user];
  }

  /**
   * @inheritdoc IRewardPool
   */
  function getManyStakingAmounts(
    address[] calldata poolIds,
    address[] calldata userList
  ) external view override returns (uint256[] memory stakingAmounts) {
    if (poolIds.length != userList.length) revert ErrInvalidArrays();
    stakingAmounts = new uint256[](poolIds.length);
    for (uint i = 0; i < stakingAmounts.length; ) {
      stakingAmounts[i] = _poolDetail[poolIds[i]].delegatingAmount[userList[i]];

      unchecked {
        ++i;
      }
    }
  }

  function _unwrapC2P(address consensusAddr) internal view returns (address) {
    return IProfile(getContract(ContractType.PROFILE)).getConsensus2Id(consensusAddr);
    // return _profileContract.getConsensus2Id(consensusAddr);
  }

  function _unwrapManyC2P(address[] memory consensusAddrs) internal view returns (address[] memory) {
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
