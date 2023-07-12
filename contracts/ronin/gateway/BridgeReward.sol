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
    address[] calldata operatorList,
    uint256[] calldata voteCountList,
    uint256 totalVoteCount,
    uint256 period
  )
    external
    onlyContract(ContractType.BRIDGE_TRACKING) // TODO: allow bridge or/and governor call this method
  {
    if (period <= _latestRewardedPeriod) revert ErrPeriodAlreadyProcessed(period, _latestRewardedPeriod);

    uint256 rewardPerVote = _rewardPerPeriod / totalVoteCount;
    uint256[] memory slashedDurationList = _getSlashInfo(operatorList);

    for (uint i; i < operatorList.length; ) {
      address iOperator = operatorList[i];
      uint256 iReward = voteCountList[i] * rewardPerVote;

      BridgeRewardInfo storage _iRewardInfo = _rewardInfo[iOperator];
      if (slashedDurationList[i] > 0) {
        _iRewardInfo.slashed += iReward;
        emit BridgeRewardSlashed(iOperator, iReward);
      } else {
        _iRewardInfo.claimed += iReward;
        if (_sendRON(payable(iOperator), iReward)) {
          emit BridgeRewardScattered(iOperator, iReward);
        } else {
          emit BridgeRewardScatterFailed(iOperator, iReward);
        }
      }

      unchecked {
        ++i;
      }
    }

    ++_latestRewardedPeriod;
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
