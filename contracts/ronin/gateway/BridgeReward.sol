// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../extensions/collections/HasContracts.sol";
import "../../extensions/RONTransferHelper.sol";
import { IBridgeReward } from "../../interfaces/bridge/IBridgeReward.sol";
import { IBridgeSlash } from "../../interfaces/bridge/IBridgeSlash.sol";
import "../../utils/CommonErrors.sol";

contract BridgeReward is IBridgeReward, HasContracts, Initializable {
  receive() external payable {}

  mapping(address => BridgeRewardInfo) internal _rewardInfo;
  uint256 internal _rewardPerPeriod;
  uint256 internal _latestRewardedPeriod;

  constructor() {
    _disableInitializers();
  }

  function initialize(
    address bridgeManagerContract,
    address bridgeTrackingContract,
    address bridgeSlashContract,
    uint256 rewardPerPeriod
  ) external {
    _setContract(ContractType.BRIDGE_MANAGER, bridgeManagerContract);
    _setContract(ContractType.BRIDGE_TRACKING, bridgeTrackingContract);
    _setContract(ContractType.BRIDGE_SLASH, bridgeSlashContract);
    _setRewardPerPeriod(rewardPerPeriod);
  }

  function execSyncReward(
    address[] calldata operators,
    uint256[] calldata ballots,
    uint256 totalBallot,
    uint256 totalVote,
    uint256 period
  )
    external
    onlyContract(ContractType.BRIDGE_TRACKING) // TODO: allow bridge or/and governor call this method
  {
    if (period <= _latestRewardedPeriod) revert ErrPeriodAlreadyProcessed(period, _latestRewardedPeriod);

    uint256[] memory slashedDurationList = _getSlashInfo(operators);
    bool iSlashed;

    if (!_validateBridgeTrackingResponse(totalBallot, totalVote, ballots) || totalBallot == 0) {
      // Shares equally in case the bridge has nothing to vote or bridge tracking response is incorrect
      uint256 rewardEach = _rewardPerPeriod / operators.length;
      for (uint i; i < operators.length; ) {
        iSlashed = period <= slashedDurationList[i];
        _updateRewardAndTransfer(operators[i], rewardEach, iSlashed);
        unchecked {
          ++i;
        }
      }
    } else {
      // Shares the bridge operators reward proportionally
      uint256 iReward;
      for (uint i; i < operators.length; ) {
        iReward = (_rewardPerPeriod * ballots[i]) / totalBallot;
        iSlashed = period <= slashedDurationList[i];
        _updateRewardAndTransfer(operators[i], iReward, iSlashed);
        unchecked {
          ++i;
        }
      }
    }

    ++_latestRewardedPeriod;
  }

  /**
   * @dev Returns whether the responses from bridge tracking are correct.
   */
  function _validateBridgeTrackingResponse(
    uint256 totalBallots,
    uint256 totalVotes,
    uint256[] memory ballots
  ) private returns (bool valid) {
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
    if (!valid) {
      emit BridgeTrackingIncorrectlyResponded();
    }
  }

  function _updateRewardAndTransfer(address operator, uint256 reward, bool slashed) private {
    BridgeRewardInfo storage _iRewardInfo = _rewardInfo[operator];
    if (slashed) {
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

  function getRewardPerPeriod() external view returns (uint256) {
    return _rewardPerPeriod;
  }

  function setRewardPerPeriod(uint256 rewardPerPeriod) external onlyContract(ContractType.BRIDGE_MANAGER) {
    _setRewardPerPeriod(rewardPerPeriod);
  }

  function _setRewardPerPeriod(uint256 rewardPerPeriod) internal {
    _rewardPerPeriod = rewardPerPeriod;
    emit UpdatedRewardPerPeriod(rewardPerPeriod);
  }

  function _getSlashInfo(address[] memory operatorList) internal returns (uint256[] memory _slashedDuration) {
    return IBridgeSlash(getContract(ContractType.BRIDGE_SLASH)).penaltyDurationOf(operatorList);
  }
}
