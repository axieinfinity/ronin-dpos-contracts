// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { LibTPoolId } from "./operations/LibTPoolId.sol";

type TPoolId is address;

using { LibTPoolId.all } for TPoolId global;
using { LibTPoolId.push } for TPoolId global;
using { LibTPoolId.unwrap } for TPoolId global;
