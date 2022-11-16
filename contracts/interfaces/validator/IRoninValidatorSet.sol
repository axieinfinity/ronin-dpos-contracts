// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./ICandidateManager.sol";
import "./info-fragments/IJailingInfo.sol";
import "./info-fragments/ITimingInfo.sol";
import "./info-fragments/IValidatorInfo.sol";
import "./ICoinbaseExecution.sol";
import "./ISlashingExecution.sol";

interface IRoninValidatorSet is
  ITimingInfo,
  IJailingInfo,
  ICandidateManager,
  IValidatorInfo,
  ISlashingExecution,
  ICoinbaseExecution
{}
