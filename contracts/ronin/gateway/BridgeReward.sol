// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../extensions/collections/HasContracts.sol";
import "../../extensions/RONTransferHelper.sol";
import { IBridgeManager } from "../../interfaces/bridge/IBridgeManager.sol";
import { IBridgeReward } from "../../interfaces/bridge/IBridgeReward.sol";
import { IBridgeSlash } from "../../interfaces/bridge/IBridgeSlash.sol";
import "../../utils/CommonErrors.sol";

contract BridgeReward is IBridgeReward, HasContracts, Initializable {
  mapping(address => BridgeRewardInfo) internal _rewardInfo;
  uint256 internal _rewardPerPeriod;
  uint256 internal _latestRewardedPeriod;

  constructor() payable {
    _disableInitializers();
  }

  function initialize(
    address bridgeManagerContract,
    address bridgeTrackingContract,
    address bridgeSlashContract,
    uint256 rewardPerPeriod
  ) external payable initializer {
    _setContract(ContractType.BRIDGE_MANAGER, bridgeManagerContract);
    _setContract(ContractType.BRIDGE_TRACKING, bridgeTrackingContract);
    _setContract(ContractType.BRIDGE_SLASH, bridgeSlashContract);
    _setRewardPerPeriod(rewardPerPeriod);
  }

  /**
   * @inheritdoc IBridgeReward
   */
  function receiveRON() external payable {}

  /**
   * @inheritdoc IBridgeReward
   */
  function execSyncReward(
    address[] calldata operators,
    uint256[] calldata ballots,
    uint256 totalBallot,
    uint256 totalVote,
    uint256 period
  ) external {
    if (msg.sender != getContract(ContractType.BRIDGE_TRACKING) && !_isBridgeOperator(msg.sender)) {
      revert ErrUnauthorizedCall(msg.sig);
    }
    if (period <= _latestRewardedPeriod) revert ErrPeriodAlreadyProcessed(period, _latestRewardedPeriod);

    // prevent reentrancy
    unchecked {
      ++_latestRewardedPeriod;
    }

    bool isSlashed;
    uint256 rewardPerPeriod = _rewardPerPeriod;
    uint256[] memory slashedDurationList = _getSlashInfo(operators);

    // Validate should share the reward equally
    bool isSharingRewardEqually = _isSharingRewardEqually(totalBallot, totalVote, ballots);

    uint256 reward;
    uint256 numBridgeOperators = operators.length;

    for (uint256 i; i < operators.length; ) {
      (reward, isSlashed) = _calcRewardAndCheckSlashedStatus(
        isSharingRewardEqually,
        numBridgeOperators,
        rewardPerPeriod,
        ballots[i],
        totalBallot,
        period,
        slashedDurationList[i]
      );

      _updateRewardAndTransfer(operators[i], reward, isSlashed);

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @dev Returns whether should share the reward equally, in case of bridge tracking returns
   * informed data or there is no ballot in a day.
   *
   * Emit a {BridgeTrackingIncorrectlyResponded} event when in case of incorrect data.
   */
  function _isSharingRewardEqually(
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

  function _calcRewardAndCheckSlashedStatus(
    bool isSharingRewardEqually,
    uint256 numBridgeOperators,
    uint256 rewardPerPeriod,
    uint256 ballot,
    uint256 totalBallots,
    uint256 period,
    uint256 slashUntilPeriod
  ) internal pure returns (uint256 reward, bool isSlashed) {
    isSlashed = _isSlashedThisPeriod(period, slashUntilPeriod);
    reward = _calcReward(isSharingRewardEqually, numBridgeOperators, rewardPerPeriod, ballot, totalBallots);
  }

  function _isSlashedThisPeriod(uint256 period, uint256 slashDuration) internal pure returns (bool) {
    return period <= slashDuration;
  }

  function _calcReward(
    bool isSharingRewardEqually,
    uint256 numBridgeOperators,
    uint256 rewardPerPeriod,
    uint256 ballot,
    uint256 totalBallots
  ) internal pure returns (uint256 reward) {
    // Shares equally in case the bridge has nothing to vote or bridge tracking response is incorrect
    // Else shares the bridge operators reward proportionally
    reward = isSharingRewardEqually ? rewardPerPeriod / numBridgeOperators : (rewardPerPeriod * ballot) / totalBallots;
  }

  function _isValidBridgeTrackingResponse(
    uint256 totalBallots,
    uint256 totalVotes,
    uint256[] memory ballots
  ) internal pure returns (bool valid) {
    valid = true;
    uint256 sumBallots;
    for (uint _i; _i < ballots.length; _i++) {
      if (ballots[_i] > totalVotes) {
        valid = false;
        break;
      }
      sumBallots += ballots[_i];
    }
    valid = valid && (sumBallots <= totalBallots);
  }

  /**
   * @dev Transfer `reward` to a `operator` or only emit event based on the operator `slashed` status.
   */
  function _updateRewardAndTransfer(address operator, uint256 reward, bool isSlashed) private {
    BridgeRewardInfo storage _iRewardInfo = _rewardInfo[operator];
    if (isSlashed) {
      _iRewardInfo.slashed += reward;
      emit BridgeRewardSlashed(operator, reward);
    } else {
      _iRewardInfo.claimed += reward;
      if (_sendRON(payable(operator), reward)) {
        emit BridgeRewardScattered(operator, reward);
      } else {
        emit BridgeRewardScatterFailed(operator, reward);
      }
    }
  }

  /**
   * @inheritdoc IBridgeReward
   */
  function getRewardPerPeriod() external view returns (uint256) {
    return _rewardPerPeriod;
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
    _rewardPerPeriod = rewardPerPeriod;
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
}
