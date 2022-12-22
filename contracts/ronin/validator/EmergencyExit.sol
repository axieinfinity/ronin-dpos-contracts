// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../extensions/RONTransferHelper.sol";
import "../../interfaces/IRoninGovernanceAdmin.sol";
import "../../interfaces/validator/IEmergencyExit.sol";
import "../../precompile-usages/PrecompileUsageSortValidators.sol";
import "../../precompile-usages/PrecompileUsagePickValidatorSet.sol";
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
  function execEmergencyExit(address _consensusAddr, uint256 _secLeftToRevoke) external onlyStakingContract {
    EmergencyExitInfo storage _info = _exitInfo[_consensusAddr];
    require(_info.recyclingAt == 0, "EmergencyExit: already requested");

    uint256 _revokingTimestamp = block.timestamp + _secLeftToRevoke;
    _setRevokingTimestamp(_candidateInfo[_consensusAddr], _revokingTimestamp);
    _emergencyExitJailedTimestamp[_consensusAddr] = _revokingTimestamp;

    uint256 _deductedAmount = _stakingContract.deductStakingAmount(_consensusAddr, _emergencyExitLockedAmount);
    if (_deductedAmount > 0) {
      emit EmergencyExitFundLocked(_consensusAddr, _deductedAmount);
      uint256 _recyclingAt = block.timestamp + _emergencyExpiryDuration;
      _lockedConsensusList.push(_consensusAddr);
      _info.lockedAmount = _deductedAmount;
      _info.recyclingAt = _recyclingAt;
      IRoninGovernanceAdmin(_getAdmin()).createEmergencyExitVote(
        _consensusAddr,
        _candidateInfo[_consensusAddr].treasuryAddr,
        block.timestamp,
        _recyclingAt
      );
    }
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
  function unlockFundForEmergencyExitRequest(address _consensusAddr, address payable _recipient) external onlyAdmin {
    uint256 _length = _lockedConsensusList.length;
    uint256 _index = _length;

    for (uint _i = 0; _i < _length; _i++) {
      if (_lockedConsensusList[_i] == _consensusAddr) {
        _index = _i;
        break;
      }
    }

    // The locked amount might be recycled.
    if (_index == _length) {
      return;
    }

    uint256 _amount = _exitInfo[_consensusAddr].lockedAmount;
    delete _exitInfo[_consensusAddr];
    _lockedConsensusList[_index] = _lockedConsensusList[_length - 1];
    _lockedConsensusList.pop();
    if (_amount > 0) {
      _fundUnlocked[_consensusAddr] = true;
      if (_unsafeSendRON(_recipient, _amount)) {
        emit EmergencyExitFundUnlocked(_consensusAddr, _recipient, _amount);
        return;
      }
      emit EmergencyExitFundUnlockFailed(_consensusAddr, _recipient, _amount, address(this).balance);
    }
  }

  /**
   * @dev Tries to recycle the locked funds from emergency exit requests.
   */
  function _tryRecycleLockedFundsFromEmergencyExits() internal {
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
   * @dev Override `CandidateManager-_removeCandidate`.
   */
  function _emergencyExitFundUnlocked(address _consensusAddr) internal virtual override returns (bool) {
    return _fundUnlocked[_consensusAddr];
  }

  /**
   * @dev Override `CandidateManager-_removeCandidate`.
   */
  function _removeCandidate(address _consensusAddr) internal override {
    delete _fundUnlocked[_consensusAddr];
    super._removeCandidate(_consensusAddr);
  }

  /**
   * @dev Override `ValidatorInfoStorage-_bridgeOperatorOf`.
   */
  function _bridgeOperatorOf(address _consensusAddr)
    internal
    view
    virtual
    override(CandidateManager, ValidatorInfoStorage)
    returns (address)
  {
    return CandidateManager._bridgeOperatorOf(_consensusAddr);
  }

  /**
   * @dev See `setEmergencyExitLockedAmount.
   */
  function _setEmergencyExitLockedAmount(uint256 _amount) internal {
    _emergencyExitLockedAmount = _amount;
    emit EmergencyExitLockedAmountUpdated(_amount);
  }

  /**
   * @dev See `setEmergencyExpiryDuration`.
   */
  function _setEmergencyExpiryDuration(uint256 _duration) internal {
    _emergencyExpiryDuration = _duration;
    emit EmergencyExpiryDurationUpdated(_duration);
  }
}
