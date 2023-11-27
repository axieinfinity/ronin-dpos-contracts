// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../interfaces/validator/ICandidateManagerCallback.sol";
import "./CandidateManager.sol";

abstract contract CandidateManagerCallback is ICandidateManagerCallback, CandidateManager {
  //                                             //
  // ----------- Staking's Callbacks ----------- //
  //                                             //

  /**
   * @inheritdoc ICandidateManagerCallback
   */
  function execApplyValidatorCandidate(
    address candidateAdmin,
    address cid,
    address payable treasuryAddr,
    uint256 commissionRate
  ) external override onlyContract(ContractType.STAKING) {
    uint256 length = _candidateIds.length;
    if (length >= maxValidatorCandidate()) revert ErrExceedsMaxNumberOfCandidate();
    if (_isValidatorCandidateById(cid)) revert ErrExistentCandidate();
    if (commissionRate > _MAX_PERCENTAGE) revert ErrInvalidCommissionRate();

    for (uint i; i < length; ) {
      ValidatorCandidate storage existentInfo = _candidateInfo[_candidateIds[i]];
      if (candidateAdmin == existentInfo.__shadowedAdmin) revert ErrExistentCandidateAdmin(candidateAdmin);
      if (treasuryAddr == existentInfo.__shadowedTreasury) revert ErrExistentTreasury(treasuryAddr);

      unchecked {
        ++i;
      }
    }

    _candidateIndex[cid] = ~length;
    _candidateIds.push(cid);

    ValidatorCandidate storage _info = _candidateInfo[cid];
    _info.__shadowedAdmin = candidateAdmin;
    _info.__shadowedConsensus = TConsensus.wrap(cid);
    _info.__shadowedTreasury = treasuryAddr;
    _info.commissionRate = commissionRate;
    emit CandidateGranted(cid, treasuryAddr, candidateAdmin);
  }

  /**
   * @inheritdoc ICandidateManagerCallback
   */
  function execRequestRenounceCandidate(
    address cid,
    uint256 secsLeft
  ) external override onlyContract(ContractType.STAKING) {
    if (_isTrustedOrg(cid)) revert ErrTrustedOrgCannotRenounce();

    ValidatorCandidate storage _info = _candidateInfo[cid];
    if (_info.revokingTimestamp != 0) revert ErrAlreadyRequestedRevokingCandidate();
    _setRevokingTimestamp(_info, block.timestamp + secsLeft);
  }

  /**
   * @inheritdoc ICandidateManagerCallback
   */
  function execRequestUpdateCommissionRate(
    address cid,
    uint256 effectiveDaysOnwards,
    uint256 commissionRate
  ) external override onlyContract(ContractType.STAKING) {
    if (_candidateCommissionChangeSchedule[cid].effectiveTimestamp != 0) {
      revert ErrAlreadyRequestedUpdatingCommissionRate();
    }
    if (commissionRate > _MAX_PERCENTAGE) revert ErrInvalidCommissionRate();
    if (effectiveDaysOnwards < _minEffectiveDaysOnwards) revert ErrInvalidEffectiveDaysOnwards();

    CommissionSchedule storage _schedule = _candidateCommissionChangeSchedule[cid];
    uint256 effectiveTimestamp = ((block.timestamp / PERIOD_DURATION) + effectiveDaysOnwards) * PERIOD_DURATION;
    _schedule.effectiveTimestamp = effectiveTimestamp;
    _schedule.commissionRate = commissionRate;

    emit CommissionRateUpdateScheduled(cid, effectiveTimestamp, commissionRate);
  }

  //                                             //
  // ----------- Profile's Callbacks ----------- //
  //                                             //

  /**
   * @inheritdoc ICandidateManagerCallback
   */
  function execChangeConsensusAddress(
    address cid,
    TConsensus newConsensusAddr
  ) external override onlyContract(ContractType.PROFILE) {
    _candidateInfo[cid].__shadowedConsensus = newConsensusAddr;
  }

  /**
   * @inheritdoc ICandidateManagerCallback
   */
  function execChangeAdminAddress(address cid, address newAdmin) external onlyContract(ContractType.PROFILE) {
    _candidateInfo[cid].__shadowedAdmin = newAdmin;
  }

  /**
   * @inheritdoc ICandidateManagerCallback
   */
  function execChangeTreasuryAddress(
    address cid,
    address payable newTreasury
  ) external onlyContract(ContractType.PROFILE) {
    _candidateInfo[cid].__shadowedTreasury = newTreasury;
  }
}
