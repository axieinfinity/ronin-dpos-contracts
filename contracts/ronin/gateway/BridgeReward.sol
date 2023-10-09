// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { BridgeTrackingHelper } from "../../extensions/bridge-operator-governance/BridgeTrackingHelper.sol";
import { ContractType, HasContracts } from "../../extensions/collections/HasContracts.sol";
import { RONTransferHelper } from "../../extensions/RONTransferHelper.sol";
import { IRoninValidatorSet } from "../../interfaces/validator/IRoninValidatorSet.sol";
import { IBridgeManager } from "../../interfaces/bridge/IBridgeManager.sol";
import { IBridgeTracking } from "../../interfaces/bridge/IBridgeTracking.sol";
import { IBridgeReward } from "../../interfaces/bridge/IBridgeReward.sol";
import { IBridgeSlash } from "../../interfaces/bridge/IBridgeSlash.sol";
import { Math } from "../../libraries/Math.sol";
import { TUint256Slot } from "../../types/Types.sol";
import { ErrSyncTooFarPeriod, ErrInvalidArguments, ErrLengthMismatch, ErrUnauthorizedCall } from "../../utils/CommonErrors.sol";

contract BridgeReward is IBridgeReward, BridgeTrackingHelper, HasContracts, RONTransferHelper, Initializable {
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeReward.rewardInfo.slot") - 1
  bytes32 private constant REWARD_INFO_SLOT = 0x518cfd198acbffe95e740cfce1af28a3f7de51f0d784893d3d72c5cc59d7062a;
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeReward.rewardPerPeriod.slot") - 1
  TUint256Slot private constant REWARD_PER_PERIOD_SLOT =
    TUint256Slot.wrap(0x90f7d557245e5dd9485f463e58974fa7cdc93c0abbd0a1afebb8f9640ec73910);
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeReward.latestRewardedPeriod.slot") - 1
  TUint256Slot private constant LATEST_REWARDED_PERIOD_SLOT =
    TUint256Slot.wrap(0x2417f25874c1cdc139a787dd21df976d40d767090442b3a2496917ecfc93b619);
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeReward.totalRewardToppedUp.slot") - 1
  TUint256Slot private constant TOTAL_REWARDS_TOPPED_UP_SLOT =
    TUint256Slot.wrap(0x9a8c9f129792436c37b7bd2d79c56132fc05bf26cc8070794648517c2a0c6c64);
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeReward.totalRewardScattered.slot") - 1
  TUint256Slot private constant TOTAL_REWARDS_SCATTERED_SLOT =
    TUint256Slot.wrap(0x3663384f6436b31a97d9c9a02f64ab8b73ead575c5b6224fa0800a6bd57f62f4);

  address private immutable _self;

  constructor() payable {
    _self = address(this);
    _disableInitializers();
  }

  function initialize(
    address bridgeManagerContract,
    address bridgeTrackingContract,
    address bridgeSlashContract,
    address validatorSetContract,
    address dposGA,
    uint256 rewardPerPeriod
  ) external payable initializer {
    _setContract(ContractType.BRIDGE_MANAGER, bridgeManagerContract);
    _setContract(ContractType.BRIDGE_TRACKING, bridgeTrackingContract);
    _setContract(ContractType.BRIDGE_SLASH, bridgeSlashContract);
    _setContract(ContractType.VALIDATOR, validatorSetContract);
    _setContract(ContractType.GOVERNANCE_ADMIN, dposGA);
    LATEST_REWARDED_PERIOD_SLOT.store(type(uint256).max);
    _setRewardPerPeriod(rewardPerPeriod);
    _receiveRON();
  }

  /**
   * @dev Helper for running upgrade script, required to only revoked once by the DPoS's governance admin.
   * The following must be assured after initializing REP2: `_lastSyncPeriod` == `{BridgeReward}.latestRewardedPeriod` == `currentPeriod()`
   */
  function initializeREP2() external onlyContract(ContractType.GOVERNANCE_ADMIN) {
    require(getLatestRewardedPeriod() == type(uint256).max, "already init rep 2");
    LATEST_REWARDED_PERIOD_SLOT.store(IRoninValidatorSet(getContract(ContractType.VALIDATOR)).currentPeriod() - 1);
    _setContract(ContractType.GOVERNANCE_ADMIN, address(0));
  }

  /**
   * @inheritdoc IBridgeReward
   */
  function receiveRON() external payable {
    _receiveRON();
  }

  /**
   * @inheritdoc IBridgeReward
   */
  function syncReward(uint256 periodLength) external {
    if (!_isBridgeOperator(msg.sender)) revert ErrUnauthorizedCall(msg.sig);

    uint256 latestRewardedPeriod = getLatestRewardedPeriod();
    uint256 currentPeriod = IRoninValidatorSet(getContract(ContractType.VALIDATOR)).currentPeriod();

    if (currentPeriod <= latestRewardedPeriod) revert ErrInvalidArguments(msg.sig);
    if (latestRewardedPeriod + periodLength > currentPeriod) revert ErrInvalidArguments(msg.sig);

    LATEST_REWARDED_PERIOD_SLOT.addAssign(periodLength);

    address[] memory operators = IBridgeManager(getContract(ContractType.BRIDGE_MANAGER)).getBridgeOperators();
    IBridgeTracking bridgeTrackingContract = IBridgeTracking(getContract(ContractType.BRIDGE_TRACKING));

    for (uint256 i = 1; i <= periodLength; ) {
      unchecked {
        _syncReward({
          operators: operators,
          ballots: bridgeTrackingContract.getManyTotalBallots(latestRewardedPeriod, operators),
          totalBallot: bridgeTrackingContract.totalBallot(latestRewardedPeriod),
          totalVote: bridgeTrackingContract.totalVote(latestRewardedPeriod),
          period: latestRewardedPeriod += i
        });

        ++i;
      }
    }
  }

  /**
   * @inheritdoc IBridgeReward
   *
   * @dev The `period` a.k.a. `latestSyncedPeriod` must equal to `latestRewardedPeriod` + 1.
   */
  function execSyncReward(
    address[] calldata operators,
    uint256[] calldata ballots,
    uint256 totalBallot,
    uint256 totalVote,
    uint256 period
  ) external onlyContract(ContractType.BRIDGE_TRACKING) {
    if (operators.length != ballots.length) revert ErrLengthMismatch(msg.sig);
    if (operators.length == 0) return;

    // Only sync the period that is after the latest rewarded period, i.e. `latestSyncedPeriod == latestRewardedPeriod + 1`.
    unchecked {
      uint256 latestRewardedPeriod = getLatestRewardedPeriod();
      if (period < latestRewardedPeriod + 1) revert ErrInvalidArguments(msg.sig);
      else if (period > latestRewardedPeriod + 1) revert ErrSyncTooFarPeriod(period, latestRewardedPeriod);
    }
    LATEST_REWARDED_PERIOD_SLOT.store(period);

    _syncReward({
      operators: operators,
      ballots: ballots,
      totalBallot: totalBallot,
      totalVote: totalVote,
      period: period
    });
  }

  /**
   * @inheritdoc IBridgeReward
   */
  function getTotalRewardToppedUp() external view returns (uint256) {
    return TOTAL_REWARDS_TOPPED_UP_SLOT.load();
  }

  /**
   * @inheritdoc IBridgeReward
   */
  function getTotalRewardScattered() external view returns (uint256) {
    return TOTAL_REWARDS_SCATTERED_SLOT.load();
  }

  /**
   * @dev Internal function to receive RON tokens as rewards and update the total topped-up rewards amount.
   */
  function _receiveRON() internal {
    // prevent transfer RON directly to logic contract
    if (address(this) == _self) revert ErrUnauthorizedCall(msg.sig);

    emit SafeReceived(msg.sender, TOTAL_REWARDS_TOPPED_UP_SLOT.load(), msg.value);
    TOTAL_REWARDS_TOPPED_UP_SLOT.addAssign(msg.value);
  }

  /**
   * @dev Internal function to synchronize and distribute rewards to bridge operators for a given period.
   * @param operators An array containing the addresses of bridge operators to receive rewards.
   * @param ballots An array containing the individual ballot counts for each bridge operator.
   * @param totalBallot The total number of available ballots for the period.
   * @param totalVote The total number of votes recorded for the period.
   * @param period The period for which the rewards are being synchronized.
   */
  function _syncReward(
    address[] memory operators,
    uint256[] memory ballots,
    uint256 totalBallot,
    uint256 totalVote,
    uint256 period
  ) internal {
    uint256 numBridgeOperators = operators.length;
    uint256 rewardPerPeriod = getRewardPerPeriod();
    uint256[] memory slashedDurationList = _getSlashInfo(operators);
    // Validate should share the reward equally
    bool shouldShareEqually = _shouldShareEqually(totalBallot, totalVote, ballots);

    uint256 reward;
    bool shouldSlash;
    uint256 sumRewards;

    for (uint256 i; i < numBridgeOperators; ) {
      (reward, shouldSlash) = _calcRewardAndCheckSlashedStatus({
        shouldShareEqually: shouldShareEqually,
        numBridgeOperators: numBridgeOperators,
        rewardPerPeriod: rewardPerPeriod,
        ballot: ballots[i],
        totalBallot: totalBallot,
        period: period,
        slashUntilPeriod: slashedDurationList[i]
      });

      sumRewards += shouldSlash ? 0 : reward;
      _updateRewardAndTransfer({ period: period, operator: operators[i], reward: reward, shouldSlash: shouldSlash });

      unchecked {
        ++i;
      }
    }

    TOTAL_REWARDS_SCATTERED_SLOT.addAssign(sumRewards);
  }

  /**
   * @dev Returns whether should share the reward equally, in case of bridge tracking returns
   * informed data or there is no ballot in a day.
   *
   * Emit a {BridgeTrackingIncorrectlyResponded} event when in case of incorrect data.
   */
  function _shouldShareEqually(
    uint256 totalBallot,
    uint256 totalVote,
    uint256[] memory ballots
  ) internal returns (bool shareEqually) {
    bool valid = _isValidBridgeTrackingResponse(totalBallot, totalVote, ballots);
    if (!valid) {
      emit BridgeTrackingIncorrectlyResponded();
    }

    return !valid || totalBallot == 0;
  }

  /**
   * @dev Internal function to calculate the reward for a bridge operator and check its slashing status.
   * @param shouldShareEqually A boolean indicating whether the reward should be shared equally among bridge operators.
   * @param numBridgeOperators The total number of bridge operators for proportional reward calculation.
   * @param rewardPerPeriod The total reward available for the period.
   * @param ballot The individual ballot count of the bridge operator for the period.
   * @param totalBallot The total number of available ballots for the period.
   * @param period The period for which the reward is being calculated.
   * @param slashUntilPeriod The period until which slashing is effective for the bridge operator.
   * @return reward The calculated reward for the bridge operator.
   * @return shouldSlash A boolean indicating whether the bridge operator should be slashed for the current period.
   */
  function _calcRewardAndCheckSlashedStatus(
    bool shouldShareEqually,
    uint256 numBridgeOperators,
    uint256 rewardPerPeriod,
    uint256 ballot,
    uint256 totalBallot,
    uint256 period,
    uint256 slashUntilPeriod
  ) internal pure returns (uint256 reward, bool shouldSlash) {
    shouldSlash = _shouldSlashedThisPeriod(period, slashUntilPeriod);
    reward = _calcReward(shouldShareEqually, numBridgeOperators, rewardPerPeriod, ballot, totalBallot);
  }

  /**
   * @dev Internal function to check if a specific period should be considered as slashed based on the slash duration.
   * @param period The period to check if it should be slashed.
   * @param slashDuration The duration until which periods should be considered as slashed.
   * @return shouldSlashed A boolean indicating whether the specified period should be slashed.
   * @notice This function is used internally to determine if a particular period should be marked as slashed based on the slash duration.
   */
  function _shouldSlashedThisPeriod(uint256 period, uint256 slashDuration) internal pure returns (bool) {
    return period <= slashDuration;
  }

  /**
   * @dev Internal function to calculate the reward for a bridge operator based on the provided parameters.
   * @param shouldShareEqually A boolean indicating whether the reward should be shared equally among bridge operators.
   * @param numBridgeOperators The total number of bridge operators for proportional reward calculation.
   * @param rewardPerPeriod The total reward available for the period.
   * @param ballot The individual ballot count of the bridge operator for the period.
   * @param totalBallot The total number of available ballots for the period.
   * @return reward The calculated reward for the bridge operator.
   */
  function _calcReward(
    bool shouldShareEqually,
    uint256 numBridgeOperators,
    uint256 rewardPerPeriod,
    uint256 ballot,
    uint256 totalBallot
  ) internal pure returns (uint256 reward) {
    // Shares equally in case the bridge has nothing to vote or bridge tracking response is incorrect
    // Else shares the bridge operators reward proportionally
    reward = shouldShareEqually ? rewardPerPeriod / numBridgeOperators : (rewardPerPeriod * ballot) / totalBallot;
  }

  /**
   * @dev Transfer `reward` to a `operator` or only emit event based on the operator `slashed` status.
   */
  function _updateRewardAndTransfer(uint256 period, address operator, uint256 reward, bool shouldSlash) private {
    BridgeRewardInfo storage _iRewardInfo = _getRewardInfo()[operator];

    if (shouldSlash) {
      _iRewardInfo.slashed += reward;
      emit BridgeRewardSlashed(period, operator, reward);
    } else {
      _iRewardInfo.claimed += reward;
      if (_unsafeSendRONLimitGas({ recipient: payable(operator), amount: reward, gas: 0 })) {
        emit BridgeRewardScattered(period, operator, reward);
      } else {
        emit BridgeRewardScatterFailed(period, operator, reward);
      }
    }
  }

  /**
   * @inheritdoc IBridgeReward
   */
  function getRewardPerPeriod() public view returns (uint256) {
    return REWARD_PER_PERIOD_SLOT.load();
  }

  /**
   * @inheritdoc IBridgeReward
   */
  function getLatestRewardedPeriod() public view returns (uint256) {
    return LATEST_REWARDED_PERIOD_SLOT.load();
  }

  /**
   * @inheritdoc IBridgeReward
   */
  function setRewardPerPeriod(uint256 rewardPerPeriod) external onlyContract(ContractType.BRIDGE_MANAGER) {
    _setRewardPerPeriod(rewardPerPeriod);
  }

  /**
   * @dev Internal function for setting the total reward per period.
   * Emit an {UpdatedRewardPerPeriod} event after set.
   */
  function _setRewardPerPeriod(uint256 rewardPerPeriod) internal {
    REWARD_PER_PERIOD_SLOT.store(rewardPerPeriod);
    emit UpdatedRewardPerPeriod(rewardPerPeriod);
  }

  /**
   * @dev Internal helper for querying slash info of a list of operators.
   */
  function _getSlashInfo(address[] memory operatorList) internal returns (uint256[] memory _slashedDuration) {
    return IBridgeSlash(getContract(ContractType.BRIDGE_SLASH)).getSlashUntilPeriodOf(operatorList);
  }

  /**
   * @dev Internal helper for querying whether an address is an operator.
   */
  function _isBridgeOperator(address operator) internal view returns (bool) {
    return IBridgeManager(getContract(ContractType.BRIDGE_MANAGER)).isBridgeOperator(operator);
  }

  /**
   * @dev Internal function to access the mapping from bridge operator => BridgeRewardInfo.
   * @return rewardInfo the mapping from bridge operator => BridgeRewardInfo.
   */
  function _getRewardInfo() internal pure returns (mapping(address => BridgeRewardInfo) storage rewardInfo) {
    assembly ("memory-safe") {
      rewardInfo.slot := REWARD_INFO_SLOT
    }
  }
}
