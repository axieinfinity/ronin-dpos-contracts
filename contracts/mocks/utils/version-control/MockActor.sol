// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ErrorHandler } from "../../../libraries/ErrorHandler.sol";

contract MockActor {
  using ErrorHandler for bool;

  address private _target;

  constructor(address target) {
    _target = target;
  }

  fallback() external payable {
    (bool success, bytes memory returnOrRevertData) = _target.call{ value: msg.value }(msg.data);
    success.handleRevert(msg.sig, returnOrRevertData);
    assembly {
      return(add(returnOrRevertData, 0x20), mload(returnOrRevertData))
    }
  }
}
