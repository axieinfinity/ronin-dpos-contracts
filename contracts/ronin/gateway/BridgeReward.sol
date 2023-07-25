// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { ContractType, HasContracts } from "../../extensions/collections/HasContracts.sol";
import { RONTransferHelper } from "../../extensions/RONTransferHelper.sol";
import { IRoninValidatorSet } from "../../interfaces/validator/IRoninValidatorSet.sol";
import { IBridgeManager } from "../../interfaces/bridge/IBridgeManager.sol";
import { IBridgeTracking } from "../../interfaces/bridge/IBridgeTracking.sol";
import { IBridgeReward } from "../../interfaces/bridge/IBridgeReward.sol";
import { IBridgeSlash } from "../../interfaces/bridge/IBridgeSlash.sol";
import { Math } from "../../libraries/Math.sol";
import { TUint256Slot } from "../../types/Types.sol";
import { ErrLengthMismatch, ErrUnauthorizedCall } from "../../utils/CommonErrors.sol";

contract BridgeReward is IBridgeReward, HasContracts, RONTransferHelper, Initializable {
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeReward.rewardInfo.slot") - 1
  bytes32 private constant REWARD_INFO_SLOT = 0x518cfd198acbffe95e740cfce1af28a3f7de51f0d784893d3d72c5cc59d7062a;
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeReward.rewardPerPeriod.slot") - 1
  TUint256Slot private constant REWARD_PER_PERIOD_SLOT =
    TUint256Slot.wrap(0x90f7d557245e5dd9485f463e58974fa7cdc93c0abbd0a1afebb8f9640ec73910);
  /// @dev value is equal to keccak256("@ronin.dpos.gateway.BridgeReward.latestRewardedPeriod.slot") - 1
  TUint256Slot private constant LATEST_REWARDED_PERIOD_SLOT =
    TUint256Slot.wrap(0x2417f25874c1cdc139a787dd21df976d40d767090442b3a2496917ecfc93b619);

  constructor() payable {
    _disableInitializers();
  }

  function initialize(
    address bridgeManagerContract,
    address bridgeTrackingContract,
    address bridgeSlashContract,
    address validatorSetContract,
    uint256 rewardPerPeriod
  ) external payable initializer {
    _setContract(ContractType.BRIDGE_MANAGER, bridgeManagerContract);
    _setContract(ContractType.BRIDGE_TRACKING, bridgeTrackingContract);
    _setContract(ContractType.BRIDGE_SLASH, bridgeSlashContract);
    _setContract(ContractType.VALIDATOR, validatorSetContract);
    _setRewardPerPeriod(rewardPerPeriod);
    _syncLatestRewardedPeriod();
  }

  /**
   * @inheritdoc IBridgeReward
   */
  function receiveRON() external payable {}

  /**
   * @inheritdoc IBridgeReward
   */
  function syncReward(uint256 periodLength) external {
    if (!_isBridgeOperator(msg.sender)) revert ErrUnauthorizedCall(msg.sig);

    uint256 latestRewardedPeriod = getLatestRewardedPeriod();
    uint256 currentPeriod = IRoninValidatorSet(getContract(ContractType.VALIDATOR)).currentPeriod();

    if (latestRewardedPeriod == 0) {
      _syncLatestRewardedPeriod();
      return;
    }
    if (currentPeriod <= latestRewardedPeriod) return;

    LATEST_REWARDED_PERIOD_SLOT.addAssign(periodLength);

    address[] memory operators = IBridgeManager(getContract(ContractType.BRIDGE_MANAGER)).getBridgeOperators();
    IBridgeTracking bridgeTrackingContract = IBridgeTracking(getContract(ContractType.BRIDGE_TRACKING));

    for (uint256 i = 1; i <= periodLength; ) {
      unchecked {
        _syncReward({
          operators: operators,
          ballots: bridgeTrackingContract.getManyTotalBallots(latestRewardedPeriod, operators),
          totalBallots: bridgeTrackingContract.totalBallots(latestRewardedPeriod),
          totalVotes: bridgeTrackingContract.totalVotes(latestRewardedPeriod),
          period: latestRewardedPeriod += i
        });

        ++i;
      }
    }
  }

  /**
   * @inheritdoc IBridgeReward
   */
  function execSyncReward(
    address[] calldata operators,
    uint256[] calldata ballots,
    uint256 totalBallots,
    uint256 totalVotes,
    uint256 period
  ) external onlyContract(ContractType.BRIDGE_TRACKING) {
    if (operators.length != ballots.length) revert ErrLengthMismatch(msg.sig);
    if (operators.length == 0) return;

    // Only sync the period that is after the latest rewarded period.
    unchecked {
      uint256 latestRewardedPeriod = getLatestRewardedPeriod();
      if (period != latestRewardedPeriod + 1) {
        // Emit event instead of revert since bridge tracking and voting process depends on this.
        emit BridgeRewardSyncTooFarPeriod(period, latestRewardedPeriod);
        _syncLatestRewardedPeriod();
        return;
      }
    }

    LATEST_REWARDED_PERIOD_SLOT.postIncrement();

    _syncReward({
      operators: operators,
      ballots: ballots,
      totalBallots: totalBallots,
      totalVotes: totalVotes,
      period: period
    });
  }

  /**
   * @dev Internal function to synchronize and distribute rewards to bridge operators for a given period.
   * @param operators An array containing the addresses of bridge operators to receive rewards.
   * @param ballots An array containing the individual ballot counts for each bridge operator.
   * @param totalBallots The total number of available ballots for the period.
   * @param totalVotes The total number of votes recorded for the period.
   * @param period The period for which the rewards are being synchronized.
   */
  function _syncReward(
    address[] memory operators,
    uint256[] memory ballots,
    uint256 totalBallots,
    uint256 totalVotes,
    uint256 period
  ) internal {
    uint256 numBridgeOperators = operators.length;
    uint256 rewardPerPeriod = getRewardPerPeriod();
    uint256[] memory slashedDurationList = _getSlashInfo(operators);
    // Validate should share the reward equally
    bool shouldShareEqually = _shouldShareEqually(totalBallots, totalVotes, ballots);

    uint256 reward;
    bool shouldSlash;

    for (uint256 i; i < numBridgeOperators; ) {
      (reward, shouldSlash) = _calcRewardAndCheckSlashedStatus({
        shouldShareEqually: shouldShareEqually,
        numBridgeOperators: numBridgeOperators,
        rewardPerPeriod: rewardPerPeriod,
        ballot: ballots[i],
        totalBallots: totalBallots,
        period: period,
        slashUntilPeriod: slashedDurationList[i]
      });

      _updateRewardAndTransfer({ period: period, operator: operators[i], reward: reward, shouldSlash: shouldSlash });

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @dev Internal function to synchronize the latest rewarded period based on the current period of the validator set contract.
   * @notice This function is used internally to synchronize the latest rewarded period with the current period of the validator set contract.
   * @notice The `currentPeriod` of the validator set contract is retrieved and stored in the `LATEST_REWARDED_PERIOD_SLOT`.
   * @notice This function ensures that the latest rewarded period is updated to reflect the current period in the validator set contract.
   */
  function _syncLatestRewardedPeriod() internal {
    LATEST_REWARDED_PERIOD_SLOT.store(IRoninValidatorSet(getContract(ContractType.VALIDATOR)).currentPeriod());
  }

  /**
   * @dev Returns whether should share the reward equally, in case of bridge tracking returns
   * informed data or there is no ballot in a day.
   *
   * Emit a {BridgeTrackingIncorrectlyResponded} event when in case of incorrect data.
   */
  function _shouldShareEqually(
    uint256 totalBallots,
    uint256 totalVotes,
    uint256[] memory ballots
  ) internal returns (bool shareEqually) {
    bool valid = _isValidBridgeTrackingResponse(totalBallots, totalVotes, ballots);
    if (!valid) {
      emit BridgeTrackingIncorrectlyResponded();
    }

    return !valid || totalBallots == 0;
  }

  /**
   * @dev Internal function to calculate the reward for a bridge operator and check its slashing status.
   * @param shouldShareEqually A boolean indicating whether the reward should be shared equally among bridge operators.
   * @param numBridgeOperators The total number of bridge operators for proportional reward calculation.
   * @param rewardPerPeriod The total reward available for the period.
   * @param ballot The individual ballot count of the bridge operator for the period.
   * @param totalBallots The total number of available ballots for the period.
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
    uint256 totalBallots,
    uint256 period,
    uint256 slashUntilPeriod
  ) internal pure returns (uint256 reward, bool shouldSlash) {
    shouldSlash = _shouldSlashedThisPeriod(period, slashUntilPeriod);
    reward = _calcReward(shouldShareEqually, numBridgeOperators, rewardPerPeriod, ballot, totalBallots);
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
   * @param totalBallots The total number of available ballots for the period.
   * @return reward The calculated reward for the bridge operator.
   */
  function _calcReward(
    bool shouldShareEqually,
    uint256 numBridgeOperators,
    uint256 rewardPerPeriod,
    uint256 ballot,
    uint256 totalBallots
  ) internal pure returns (uint256 reward) {
    // Shares equally in case the bridge has nothing to vote or bridge tracking response is incorrect
    // Else shares the bridge operators reward proportionally
    reward = shouldShareEqually ? rewardPerPeriod / numBridgeOperators : (rewardPerPeriod * ballot) / totalBallots;
  }

  /**
   * @dev Internal function to validate the bridge tracking response for a given set of ballots.
   * @param totalBallots The total number of ballots available for the tracking response.
   * @param totalVotes The total number of votes recorded in the tracking response.
   * @param ballots An array containing the individual ballot counts in the tracking response.
   * @return valid A boolean indicating whether the bridge tracking response is valid or not.
   * @notice The function checks if each individual ballot count is not greater than the total votes recorded.
   * @notice It also verifies that the sum of all individual ballot counts does not exceed the total available ballots.
   */
  function _isValidBridgeTrackingResponse(
    uint256 totalBallots,
    uint256 totalVotes,
    uint256[] memory ballots
  ) internal pure returns (bool valid) {
    valid = true;
    uint256 sumBallots;
    uint256 length = ballots.length;

    unchecked {
      for (uint256 i; i < length; ++i) {
        if (ballots[i] > totalVotes) {
          valid = false;
          break;
        }

        sumBallots += ballots[i];
      }
    }

    valid = valid && (sumBallots <= totalBallots);
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
