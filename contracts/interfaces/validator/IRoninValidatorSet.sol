// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./ICandidateManager.sol";
import "./info-fragments/ICommonInfo.sol";
import "./ICoinbaseExecution.sol";
import "./ISlashingExecution.sol";
import "./IEmergencyExit.sol";

interface IRoninValidatorSet is
  ICandidateManager,
  ICommonInfo,
  ISlashingExecution,
  ICoinbaseExecution,
  IEmergencyExit
{}
