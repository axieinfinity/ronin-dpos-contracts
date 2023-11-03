// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../interfaces/validator/ICandidateManagerCallback.sol";
import "./CandidateManager.sol";

abstract contract CandidateManagerCallback is ICandidateManagerCallback, CandidateManager {
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
