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
  function execEmergencyExit(address _consensusAddr, uint256 _secLeftToRevoke) external onlyStakingContract {
    EmergencyExitInfo storage _info = _exitInfo[_consensusAddr];
    if (_info.recyclingAt != 0) revert ErrAlreadyRequestedEmergencyExit();

    uint256 _revokingTimestamp = block.timestamp + _secLeftToRevoke;
    _setRevokingTimestamp(_candidateInfo[_consensusAddr], _revokingTimestamp);
    _emergencyExitJailedTimestamp[_consensusAddr] = _revokingTimestamp;
    _bridgeRewardDeprecatedAtPeriod[_consensusAddr][currentPeriod()] = true;

    uint256 _deductedAmount = _stakingContract.execDeductStakingAmount(_consensusAddr, _emergencyExitLockedAmount);
    if (_deductedAmount > 0) {
      uint256 _recyclingAt = block.timestamp + _emergencyExpiryDuration;
      _lockedConsensusList.push(_consensusAddr);
      _info.lockedAmount = _deductedAmount;
      _info.recyclingAt = _recyclingAt;
      IRoninGovernanceAdmin(_getAdmin()).createEmergencyExitPoll(
        _consensusAddr,
        _candidateInfo[_consensusAddr].treasuryAddr,
        block.timestamp,
        _recyclingAt
      );
    }
    emit EmergencyExitRequested(_consensusAddr, _deductedAmount);
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
  function execReleaseLockedFundForEmergencyExitRequest(address _consensusAddr, address payable _recipient)
    external
    onlyAdmin
  {
    if (_exitInfo[_consensusAddr].recyclingAt == 0) {
      return;
    }

    uint256 _length = _lockedConsensusList.length;
    uint256 _index = _length;

    for (uint _i; _i < _length; ) {
      if (_lockedConsensusList[_i] == _consensusAddr) {
        _index = _i;
        break;
      }

      unchecked {
        ++_i;
      }
    }

    // The locked amount might be recycled
    if (_index == _length) {
      return;
    }

    uint256 _amount = _exitInfo[_consensusAddr].lockedAmount;
    if (_amount > 0) {
      delete _exitInfo[_consensusAddr];
      if (_length > 1) {
        _lockedConsensusList[_index] = _lockedConsensusList[_length - 1];
      }
      _lockedConsensusList.pop();

      _lockedFundReleased[_consensusAddr] = true;
      if (_unsafeSendRON(_recipient, _amount, DEFAULT_ADDITION_GAS)) {
        emit EmergencyExitLockedFundReleased(_consensusAddr, _recipient, _amount);
        return;
      }

      emit EmergencyExitLockedFundReleasingFailed(_consensusAddr, _recipient, _amount, address(this).balance);
    }
  }

  /**
   * @dev Tries to recycle the locked funds from emergency exit requests.
   */
  function _tryRecycleLockedFundsFromEmergencyExits() internal {
    assembly {
      let length := sload(_lockedConsensusList.slot)
      mstore(0x00, _lockedConsensusList.slot)
      let offset := keccak256(0x00, 0x20)

      mstore(0x20, _exitInfo.slot)
      let i
      let totalDeprecatedReward_ := sload(_totalDeprecatedReward.slot)
      for {

      } lt(i, length) {

      } {
        let idxOffset := add(offset, i)
        let addr := sload(idxOffset)
        mstore(0x00, addr)
        let key := keccak256(0x00, 0x40)

        let recyclingAtKey := add(1, key)
        if iszero(gt(sload(recyclingAtKey), timestamp())) {
          totalDeprecatedReward_ := add(totalDeprecatedReward_, sload(key))

          /// @dev delete _exitInfo[_addr]
          sstore(key, 0) // delete lockedAmount
          sstore(recyclingAtKey, 0) // delete recyclingAt

          length := sub(length, 1)
          if iszero(iszero(length)) {
            let tailOffset := add(offset, length)
            sstore(idxOffset, tailOffset)

            // /// @dev remove tail
            // sstore(tailOffset, 0)
          }

          continue
        }

        i := add(1, i)
      }

      sstore(_lockedConsensusList.slot, length)
      sstore(_totalDeprecatedReward.slot, totalDeprecatedReward_)
    }
  }

  /**
   * @dev Override `CandidateManager-_emergencyExitLockedFundReleased`.
   */
  function _emergencyExitLockedFundReleased(address _consensusAddr) internal virtual override returns (bool yes) {
    assembly {
      mstore(0x00, _consensusAddr)
      mstore(0x20, _lockedFundReleased.slot)
      yes := and(sload(keccak256(0x00, 0x40)), 0xff)
    }
  }

  /**
   * @dev Override `CandidateManager-_removeCandidate`.
   */
  function _removeCandidate(address _consensusAddr) internal override {
    assembly {
      mstore(0x00, _consensusAddr)
      mstore(0x20, _lockedFundReleased.slot)
      sstore(keccak256(0x00, 0x40), 0)
    }
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
