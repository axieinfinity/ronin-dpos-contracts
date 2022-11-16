// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IJailingInfo.sol";
import "./ITimingInfo.sol";
import "./IValidatorInfo.sol";

interface ICommonInfo is ITimingInfo, IJailingInfo, IValidatorInfo {}
