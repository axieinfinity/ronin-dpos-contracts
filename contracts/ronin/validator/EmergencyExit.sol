// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/collections/HasBridgeTrackingContract.sol";
import "../../extensions/collections/HasMaintenanceContract.sol";
import "../../extensions/collections/HasSlashIndicatorContract.sol";
import "../../extensions/collections/HasStakingVestingContract.sol";
import "../../extensions/RONTransferHelper.sol";
import "../../interfaces/validator/ICoinbaseExecution.sol";
import "../../libraries/EnumFlags.sol";
import "../../libraries/Math.sol";
import "../../precompile-usages/PrecompileUsageSortValidators.sol";
import "../../precompile-usages/PrecompileUsagePickValidatorSet.sol";
import "./storage-fragments/CommonStorage.sol";
import "./CandidateManager.sol";

abstract contract EmergencyExit is ICoinbaseExecution, RONTransferHelper, CandidateManager, CommonStorage {
  struct EmergencyExitInfo {
    uint256 lockedAmount;
    // The timestamp that this locked amount will be recycled to staking vesting contract
    uint256 recyclingAt;
  }

  uint256 public emergencyExitLockedAmount;

  address[] internal _lockedConsensusList;

  /// @dev Mapping from consensus => exit request
  mapping(address => EmergencyExitInfo) internal _exitInfo;

  function execEmergencyExit(address _consensusAddr, uint256 _secLeftToRevoke) external onlyStakingContract {
    EmergencyExitInfo storage _info = _exitInfo[_consensusAddr];
    require(_info.recyclingAt == 0, "EmergencyExit: already requested");

    uint256 _revokingTimestamp = block.timestamp + _secLeftToRevoke;
    _setRevokingTimestamp(_candidateInfo[_consensusAddr], _revokingTimestamp);
    _bridgeOperatorJailedTimestamp[_consensusAddr] = _revokingTimestamp;

    uint256 _deductedAmount = _stakingContract.deductStakingAmount(_consensusAddr, emergencyExitLockedAmount);
    if (_deductedAmount > 0) {
      _lockedConsensusList.push(_consensusAddr);
      _info.lockedAmount = _deductedAmount;
      _info.recyclingAt = block.timestamp + 14 days; // TODO
      // sends request to GA
    }
  }

  /**
   * @dev _.
   */
  function unlockFundForEmergencyExitRequest(address _consensusAddr, address payable _recipient) external onlyAdmin {
    uint256 _length = _lockedConsensusList.length;
    uint256 _index = _length;

    for (uint _i = 0; _i < _length; _i++) {
      if (_lockedConsensusList[_i] == _consensusAddr) {
        _index = _i;
        break;
      }
    }

    // The locked amount might be recycled
    if (_index == _length) {
      return;
    }

    uint256 _amount = _exitInfo[_consensusAddr].lockedAmount;
    if (_amount > 0) {
      if (_unsafeSendRON(_recipient, _amount)) {
        // emit Event(_consensusAddr, _recipient, _amount);
        return;
      }
      // emit EventFailed(_consensusAddr, _recipient, _amount, address(this).balance);
    }

    delete _exitInfo[_consensusAddr];
    _lockedConsensusList[_index] = _lockedConsensusList[_length - 1];
    _lockedConsensusList.pop();
  }

  /**
   * @dev _.
   */
  function _tryRecycleLockedAmounts() internal {
    uint256 _length = _lockedConsensusList.length;

    uint256 _i;
    address _addr;
    EmergencyExitInfo storage _info;

    while (_i < _length) {
      _addr = _lockedConsensusList[_i];
      _info = _exitInfo[_addr];

      if (_info.recyclingAt <= block.timestamp) {
        _totalDeprecatedReward += _info.lockedAmount;

        delete _exitInfo[_addr];
        _lockedConsensusList[_i] = _lockedConsensusList[--_length];
        _lockedConsensusList.pop();
        continue;
      }

      _i++;
    }
  }

  /**
   * @inheritdoc IValidatorInfo
   */
  function bridgeOperatorOf(address _consensusAddr)
    public
    view
    virtual
    override(CandidateManager, IValidatorInfo, ValidatorInfoStorage)
    returns (address)
  {
    return CandidateManager.bridgeOperatorOf(_consensusAddr);
  }
}
