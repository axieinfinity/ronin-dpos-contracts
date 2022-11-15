// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./managers/ICandidateManager.sol";
import "./managers/ISlashingInfoManager.sol";
import "./managers/ITimingManager.sol";
import "./managers/IValidatorManager.sol";
import "./fragments/IValidatorSetFragmentCoinbase.sol";
import "./fragments/IValidatorSetFragmentSlashing.sol";

interface IRoninValidatorSet is
  ITimingManager,
  ISlashingInfoManager,
  ICandidateManager,
  IValidatorManager,
  IValidatorSetFragmentCoinbase,
  IValidatorSetFragmentSlashing
{}
