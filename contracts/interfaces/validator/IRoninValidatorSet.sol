// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IBaseRoninValidatorSet.sol";
import "./IRoninValidatorSetCommon.sol";
import "./IRoninValidatorSetSlashing.sol";
import "./IRoninValidatorSetCoinbase.sol";

interface IRoninValidatorSet is
  IBaseRoninValidatorSet,
  IRoninValidatorSetCommon,
  IRoninValidatorSetSlashing,
  IRoninValidatorSetCoinbase
{}
