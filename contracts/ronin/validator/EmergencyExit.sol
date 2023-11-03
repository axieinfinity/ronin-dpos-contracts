// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/RONTransferHelper.sol";
import "../../interfaces/IRoninGovernanceAdmin.sol";
import "../../interfaces/validator/IEmergencyExit.sol";
import "./storage-fragments/CommonStorage.sol";
import "./CandidateManager.sol";

abstract contract EmergencyExit is IEmergencyExit, RONTransferHelper, CandidateManager, CommonStorage {
  /**
   * @inheritdoc IEmergencyExit
   */
  function emergencyExitLockedAmount() external view returns (uint256) {
    return _emergencyExitLockedAmount;
  }

  /**
   * @inheritdoc IEmergencyExit
   */
  function emergencyExpiryDuration() external view returns (uint256) {
    return _emergencyExpiryDuration;
  }

  /**
   * @inheritdoc IEmergencyExit
   */
  function execEmergencyExit(address cid, uint256 secLeftToRevoke) external onlyContract(ContractType.STAKING) {
    EmergencyExitInfo storage _info = _exitInfo[cid];
    if (_info.recyclingAt != 0) revert ErrAlreadyRequestedEmergencyExit();

    uint256 revokingTimestamp = block.timestamp + secLeftToRevoke;
    _setRevokingTimestamp(_candidateInfo[cid], revokingTimestamp);
    _emergencyExitJailedTimestamp[cid] = revokingTimestamp;

    uint256 deductedAmount = IStaking(msg.sender).execDeductStakingAmount(cid, _emergencyExitLockedAmount);
    if (deductedAmount > 0) {
      uint256 recyclingAt = block.timestamp + _emergencyExpiryDuration;
      _lockedConsensusList.push(cid);
      _info.lockedAmount = deductedAmount;
      _info.recyclingAt = recyclingAt;
      IRoninGovernanceAdmin(_getAdmin()).createEmergencyExitPoll(
        cid,
        _candidateInfo[cid].__shadowedTreasury,
        block.timestamp,
        recyclingAt
      );
    }
    emit EmergencyExitRequested(cid, deductedAmount);
  }

  /**
   * @inheritdoc IEmergencyExit
   */
  function setEmergencyExitLockedAmount(uint256 _emergencyExitLockedAmount) external onlyAdmin {
    _setEmergencyExitLockedAmount(_emergencyExitLockedAmount);
  }

  /**
   * @inheritdoc IEmergencyExit
   */
  function setEmergencyExpiryDuration(uint256 _emergencyExpiryDuration) external onlyAdmin {
    _setEmergencyExpiryDuration(_emergencyExpiryDuration);
  }

  /**
   * @inheritdoc IEmergencyExit
   */
  function execReleaseLockedFundForEmergencyExitRequest(address cid, address payable recipient) external onlyAdmin {
    if (_exitInfo[cid].recyclingAt == 0) {
      return;
    }

    uint256 length = _lockedConsensusList.length;
    uint256 index = length;

    for (uint i; i < length; ) {
      if (_lockedConsensusList[i] == cid) {
        index = i;
        break;
      }

      unchecked {
        ++i;
      }
    }

    // The locked amount might be recycled
    if (index == length) {
      return;
    }

    uint256 amount = _exitInfo[cid].lockedAmount;
    if (amount > 0) {
      delete _exitInfo[cid];
      if (length > 1) {
        _lockedConsensusList[index] = _lockedConsensusList[length - 1];
      }
      _lockedConsensusList.pop();

      _lockedFundReleased[cid] = true;
      if (_unsafeSendRONLimitGas(recipient, amount, DEFAULT_ADDITION_GAS)) {
        emit EmergencyExitLockedFundReleased(cid, recipient, amount);
        return;
      }

      emit EmergencyExitLockedFundReleasingFailed(cid, recipient, amount, address(this).balance);
    }
  }

  /**
   * @dev Tries to recycle the locked funds from emergency exit requests.
   */
  function _tryRecycleLockedFundsFromEmergencyExits() internal {
    uint256 length = _lockedConsensusList.length;

    uint256 i;
    address addr;
    EmergencyExitInfo storage _info;

    while (i < length) {
      addr = _lockedConsensusList[i];
      _info = _exitInfo[addr];

      if (_info.recyclingAt <= block.timestamp) {
        _totalDeprecatedReward += _info.lockedAmount;

        delete _exitInfo[addr];
        if (--length > 0) {
          _lockedConsensusList[i] = _lockedConsensusList[length];
        }
        _lockedConsensusList.pop();
        continue;
      }

      unchecked {
        i++;
      }
    }
  }

  /**
   * @dev Override `CandidateManager-_emergencyExitLockedFundReleased`.
   */
  function _emergencyExitLockedFundReleased(address cid) internal virtual override returns (bool) {
    return _lockedFundReleased[cid];
  }

  /**
   * @dev Override `CandidateManager-_removeCandidate`.
   */
  function _removeCandidate(address cid) internal override {
    delete _lockedFundReleased[cid];
    super._removeCandidate(cid);
  }

  function __css2cid(
    TConsensus consensusAddr
  ) internal view virtual override(CandidateManager, CommonStorage) returns (address) {
    return CandidateManager.__css2cid(consensusAddr);
  }

  function __css2cidBatch(
    TConsensus[] memory consensusAddrs
  ) internal view virtual override(CandidateManager, CommonStorage) returns (address[] memory) {
    return CandidateManager.__css2cidBatch(consensusAddrs);
  }

  /**
   * @dev See `setEmergencyExitLockedAmount.
   */
  function _setEmergencyExitLockedAmount(uint256 amount) internal {
    _emergencyExitLockedAmount = amount;
    emit EmergencyExitLockedAmountUpdated(amount);
  }

  /**
   * @dev See `setEmergencyExpiryDuration`.
   */
  function _setEmergencyExpiryDuration(uint256 duration) internal {
    _emergencyExpiryDuration = duration;
    emit EmergencyExpiryDurationUpdated(duration);
  }
}
