// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../extensions/collections/HasContracts.sol";

contract BridgeReward is HasContracts, Initializable {
  struct BridgeRewardInfo {
    uint256 claimed;
    uint256 slashed;
  }

  /// @dev Event emitted when the reward per period config is updated.
  event UpdatedRewardPerPeriod(uint256 newRewardPerPeriod);
  /// @dev Event emitted when the reward of the `operator` is scattered with `amount`.
  event BridgeRewardScattered(address operator, uint256 amount);
  /// @dev Event emitted when the reward of the `operator` is slashed with `amount`.
  event BridgeRewardSlashed(address operator, uint256 amount);
  /// @dev Event emitted when the reward of the `operator` is scattered with `amount` but failed to transfer.
  event BridgeRewardScatterFailed(address operator, uint256 amount);

  receive() external payable {}

  mapping(address => BridgeRewardInfo) internal _rewardInfo;
  uint256 internal _rewardPerPeriod;

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
    uint256 totalVoteCount
  ) external onlyContract(ContractType.BRIDGE_TRACKING) {
    uint256 rewardPerVote = _rewardPerPeriod / totalVoteCount;
    bool[] memory slashedList = _getSlashInfo(operatorList);

    for (uint i; i < operatorList.length; ) {
      address iOperator = operatorList[i];
      uint256 iReward = voteCountList[i] * rewardPerVote;

      BridgeRewardInfo storage _iRewardInfo = _rewardInfo[iOperator];
      if (slashedList[i]) {
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

  function _getSlashInfo(address[] memory operatorList) internal returns (bool[] memory _slashed) {}
}
